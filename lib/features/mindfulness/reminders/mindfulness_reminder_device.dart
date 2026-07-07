import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'mindfulness_reminder_controller.dart';

/// Device implementation of the mindfulness reminder seams, backing
/// [MindfulnessReminderScheduler] and [MindfulnessReminderNotifier] with
/// `flutter_local_notifications`.
///
/// Same judgment call as the hydration device: the exact-alarm "wake and
/// re-check" flow (android_alarm_manager_plus background callback) is deferred
/// to on-device wiring; [schedule] posts a zoned notification at the trigger
/// time via `zonedSchedule`.
class MindfulnessReminderDevice
    implements MindfulnessReminderScheduler, MindfulnessReminderNotifier {
  MindfulnessReminderDevice(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const int _notificationId = 5002;
  static const String _channelId = 'mindfulness_reminders';
  static const String _channelName = 'Mindfulness reminders';

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'A daily nudge to take mindful minutes.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  @override
  Future<void> schedule(DateTime triggerAt) async {
    // TODO(phase8-native-widget): mirror Kotlin's exact alarm + goal re-check on
    // device (android_alarm_manager_plus). Deferred.
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Take a mindful moment',
      body: 'A few mindful minutes can reset your day.',
      scheduledDate: tz.TZDateTime.from(triggerAt, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _notificationId);

  @override
  Future<void> showMindfulnessReminder(
    double currentMinutes,
    double dailyGoalMinutes,
  ) async {
    final body = dailyGoalMinutes > 0.0
        ? 'You have ${currentMinutes.toStringAsFixed(0)} of '
            '${dailyGoalMinutes.toStringAsFixed(0)} mindful minutes today.'
        : 'Take a few mindful minutes.';
    await _plugin.show(
      id: _notificationId,
      title: 'Take a mindful moment',
      body: body,
      notificationDetails: _details(),
    );
  }

  @override
  Future<void> cancelReminderNotification() =>
      _plugin.cancel(id: _notificationId);
}
