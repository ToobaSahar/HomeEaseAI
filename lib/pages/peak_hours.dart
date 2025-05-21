/*import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> fetchAndSchedulePeakHour() async {
  final now = DateTime.now();
  final currentMonth = DateFormat('MMMM').format(now); // e.g. "May"

  final doc = await FirebaseFirestore.instance
      .collection('peak_hours')
      .doc(currentMonth)
      .get();

  if (doc.exists) {
    final peakTimeStr = doc['peakTime']; // Example: "21:30"
    final parts = peakTimeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final peakTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time hasn't passed today
    if (peakTime.isAfter(now)) {
      await schedulePeakNotification(peakTime);
    }
  }
}

Future<void> schedulePeakNotification(DateTime peakTime) async {
  final notificationTime = peakTime.subtract(Duration(minutes: 15));

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    '⚡ Peak Hour Alert',
    'Peak hour starts at ${DateFormat.Hm().format(peakTime)}. Reduce usage!',
    tz.TZDateTime.from(notificationTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'peak_channel',
        'Peak Alerts',
        channelDescription: 'Notify during peak electricity times',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
  );
}
*/