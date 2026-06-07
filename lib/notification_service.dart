import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _scheduling = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    try {
      const tzChannel = MethodChannel('com.example.reminder_app/timezone');
      final timezoneName =
          await tzChannel.invokeMethod<String>('getLocalTimezone') ?? 'UTC';
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    });
  }

  Future<void> scheduleAll() async {
    if (!_initialized || _scheduling) return;
    _scheduling = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await _plugin.cancelAll();
      } catch (e) {
        debugPrint('[Notifications] cancelAll error: $e');
      }

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('reminders')
            .get();

        for (final doc in snapshot.docs) {
          await _scheduleOne(doc.id, doc.data());
        }
        debugPrint(
            '[Notifications] scheduled ${snapshot.docs.length} reminder(s)');
      } catch (e) {
        debugPrint('[Notifications] scheduleAll error: $e');
      }
    } finally {
      _scheduling = false;
    }
  }

  Future<void> _scheduleOne(
      String docId, Map<String, dynamic> data) async {
    final timeStr = (data['time'] ?? '').toString();
    final parts = timeStr.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final title = (data['title'] ?? 'Medication').toString();
    final dosage = (data['dosage'] ?? '').toString();
    final body = dosage.isNotEmpty ? dosage : 'Time to take your medication';
    final repeatType = (data['repeatType'] ?? 'daily').toString();

    const androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Reminds you to take your medication on time',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails);
    final id = _notifId(docId);
    final now = tz.TZDateTime.now(tz.local);

    if (repeatType == 'daily') {
      final next = _nextOccurrence(now, hour, minute, null);
      await _schedule(id, title, body, next, details,
          match: DateTimeComponents.time);
    } else if (repeatType == 'once') {
      final startDateStr = data['startDate'] as String?;
      if (startDateStr == null || startDateStr.isEmpty) return;
      final startDate = DateTime.tryParse(startDateStr);
      if (startDate == null) return;
      final scheduled = tz.TZDateTime(tz.local, startDate.year,
          startDate.month, startDate.day, hour, minute);
      if (scheduled.isBefore(now)) return;
      await _schedule(id, title, body, scheduled, details);
    } else if (repeatType == 'weekly') {
      final weekday = data['weekday'] as int?;
      if (weekday == null) return;
      final next = _nextOccurrence(now, hour, minute, weekday);
      await _schedule(id, title, body, next, details,
          match: DateTimeComponents.dayOfWeekAndTime);
    }
  }

  tz.TZDateTime _nextOccurrence(
      tz.TZDateTime now, int hour, int minute, int? weekday) {
    var candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (candidate.isBefore(now) ||
        (weekday != null && candidate.weekday != weekday)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  Future<void> _schedule(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    NotificationDetails details, {
    DateTimeComponents? match,
  }) async {
    for (final mode in [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id, title, body, when, details,
          androidScheduleMode: mode,
          matchDateTimeComponents: match,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return;
      } catch (_) {}
    }
    debugPrint('[Notifications] failed to schedule $id');
  }

  int _notifId(String docId) => docId.hashCode.abs() % 100000;
}
