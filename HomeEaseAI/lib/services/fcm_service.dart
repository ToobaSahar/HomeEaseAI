import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initFCM(String userId) async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // ✅ Explicitly request notification permission (especially important for iOS and Android 13+)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('✅ User granted notification permission');

    // ✅ Get FCM token
    String? token = await messaging.getToken();
    print("📱 FCM Token: $token");

    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }

    // ✅ Update token in Firestore if it changes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcmToken': newToken});
    });

    // ✅ Show push notification info when app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      print('📩 Push Notification Received: ${message.notification?.title}');
    });
  } else {
    print('❌ User denied or has not granted notification permission');
  }
}
