import admin from "firebase-admin";

console.log("🔐 ENV CHECK:", process.env.FIREBASE_SERVICE_ACCOUNT?.length);

let app;
try {
  if (!admin.apps.length) {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  }
} catch (error) {
  console.error("❌ Firebase Init Error:", error);
  // You must handle this inside the handler
}

// Declare Firestore outside for reuse
const db = admin.firestore();

function isCurrentTimeInPeakHours(peakHoursArray) {
  const now = new Date();
  const currentMinutes = now.getHours() * 60 + now.getMinutes();

  for (const slot of peakHoursArray) {
    const [startHour, startMinute] = slot.startTime.split(":").map(Number);
    const [endHour, endMinute] = slot.endTime.split(":").map(Number);

    const startMinutes = startHour * 60 + startMinute;
    const endMinutes = endHour * 60 + endMinute;

    if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
      return true;
    }
  }

  return false;
}

export default async function handler(req, res) {
   const { secret } = req.query;

  console.log("🔐 Received Secret:", secret);
  console.log("🔐 Expected Secret:", process.env.CRON_SECRET);
  // Require a secret to access
 if (secret !== process.env.CRON_SECRET) {
    console.log("❌ Wrong secret:", secret);
    console.log("🧪 Raw secret query param:", req.query.secret);
    return res.status(401).json({ error: "Unauthorized" });
  }


  if (!admin.apps.length) {
    return res.status(500).send("Firebase not initialized");
  }

  const now = new Date();
  const month = now.toLocaleString("en-US", { month: "long" }).toLowerCase();

  const peakDoc = await db.collection("peak_hours").doc("pakistan_monthly").get();
  const peakData = peakDoc.data();

  const peakHoursArray = peakData[month]?.slots;

  if (!peakHoursArray || !Array.isArray(peakHoursArray)) {
    console.log(`⚠️ No peak hour data for ${month}`);
    return res.status(200).send("No peak hour data");
  }

  const inPeakTime = isCurrentTimeInPeakHours(peakHoursArray);

  if (!inPeakTime) {
    console.log("⏱️ Not peak hours. Skipping notifications.");
    return res.status(200).send("Not peak hours");
  }

  const usersSnapshot = await db.collection("users").get();

  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const token = userData.fcmToken;

    if (token) {
      try {
        await admin.messaging().send({
          notification: {
            title: "⚠️ Peak Energy Hour",
            body: "Avoid running heavy appliances right now to save energy!",
          },
          token: token,
        });
        console.log(`✅ Sent to ${doc.id}`);
      } catch (error) {
        console.error(`❌ Error sending to ${doc.id}:`, error);
      }
    }
  }

  res.status(200).send("✅ Notifications sent.");
}
