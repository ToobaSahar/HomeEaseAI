// api/analyze-bill.js

import fetch from 'node-fetch';
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

if (!getApps().length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  initializeApp({
    credential: cert(serviceAccount),
  });
}
const db = getFirestore();

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { base64Image, userId } = req.body;

  if (!base64Image || !userId) {
    return res.status(400).json({ error: 'Missing image or user ID' });
  }

  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

  try {
    // 🔄 Fetch user appliances from Firestore
    const userDoc = await db.collection('users').doc(userId).get();
    const appliances = userDoc.exists ? userDoc.data().appliances || [] : [];
    const applianceList = appliances.length > 0 ? appliances.join(', ') : 'no appliances listed';

    // 📄 Build prompt with appliance context
    const promptText = `
This is an electricity bill image. The user owns the following appliances: ${applianceList}.
1. Extract total units, total amount, and any usage-related notes from the image.
2. Then suggest 3–5 personalized ways to reduce electricity consumption, keeping those appliances in mind.
`;

    const body = {
      contents: [
        {
          parts: [
            { text: promptText },
            {
              inlineData: {
                mimeType: "image/jpeg",
                data: base64Image
              }
            }
          ]
        }
      ]
    };

    const response = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });

    const result = await response.json();
    const text = result?.candidates?.[0]?.content?.parts?.[0]?.text ?? 'No result found';
    res.status(200).json({ message: text });
  } catch (error) {
    console.error('Gemini API error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
