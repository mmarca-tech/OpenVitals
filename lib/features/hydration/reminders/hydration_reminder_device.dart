import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hydration_reminder_controller.dart';

/// Device implementation of the hydration reminder seams, backing
/// [HydrationReminderScheduler] and [HydrationReminderNotifier] with
/// `flutter_local_notifications`.
///
/// Judgment call: the Kotlin app arms an exact `AlarmManager` alarm that wakes
/// the app so it can re-read today's intake and decide whether to notify. The
/// equivalent Dart "wake a background isolate and re-check the goal at fire
/// time" needs `android_alarm_manager_plus` with a top-level callback and is
/// left for on-device wiring (Phase 8 platform work). Here we take the approach
/// the port brief allows: [schedule] posts a zoned notification directly at the
/// trigger time via `zonedSchedule`. [showHydrationReminder] posts immediately
/// (used when the controller is driven by an already-woken alarm callback).
class HydrationReminderDevice
    implements HydrationReminderScheduler, HydrationReminderNotifier {
  HydrationReminderDevice(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const int _notificationId = 5001;
  static const String _channelId = 'hydration_reminders';
  static const String _channelName = 'Hydration reminders';

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminders to drink water throughout the day.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      );

  @override
  Future<void> schedule(DateTime triggerAt) async {
    // TODO(phase8-native-widget): to mirror Kotlin exactly, arm an exact alarm
    // (android_alarm_manager_plus) that wakes the app to re-check today's
    // hydration before notifying. Deferred to on-device wiring.
    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'Time to hydrate',
      body: 'Log some water to stay on track with your daily goal.',
      scheduledDate: tz.TZDateTime.from(triggerAt, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _notificationId);

  @override
  Future<void> showHydrationReminder(
    double currentLiters,
    double dailyGoalLiters,
  ) async {
    final body = dailyGoalLiters > 0.0
        ? 'You have logged ${currentLiters.toStringAsFixed(1)} L of '
            '${dailyGoalLiters.toStringAsFixed(1)} L today.'
        : 'Log some water to stay hydrated.';
    await _plugin.show(
      id: _notificationId,
      title: 'Time to hydrate',
      body: body,
      notificationDetails: _details(),
    );
  }

  @override
  Future<void> cancelReminderNotification() =>
      _plugin.cancel(id: _notificationId);
}
