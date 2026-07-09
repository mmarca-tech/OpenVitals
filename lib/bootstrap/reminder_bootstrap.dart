import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/reminders/alarm_manager_reminder_scheduler.dart';
import '../core/reminders/reminder_notifications.dart';
import '../core/reminders/reminder_time_zone.dart';
import '../di/providers.dart';

/// Brings the reminder subsystem up at app start, standing in for the Kotlin
/// boot receivers and `Application.onCreate` wiring.
///
/// Order matters:
/// 1. the time-zone database, before anything can call `zonedSchedule`;
/// 2. the notification plugin, before anything can post;
/// 3. the alarm manager service, before an alarm can be armed;
/// 4. re-arm each reminder's schedule.
///
/// Step 4 is what the Kotlin `HydrationReminderBootReceiver` did. It is still
/// needed even though the alarm is `rescheduleOnReboot`: an app *update*
/// (`MY_PACKAGE_REPLACED`) invalidates the stored callback handle, and a user
/// who enables a reminder then force-stops the app leaves nothing armed.
///
/// Every step is best-effort and independently guarded: a device that refuses
/// notifications, or a host with no alarm manager, must not stop the app from
/// starting. Returns the steps that succeeded, for logging and tests.
Future<ReminderBootstrapResult> bootstrapReminders(
  ProviderContainer container, {
  Future<bool> Function() initializeTimeZone = initializeReminderTimeZone,
  AndroidAlarmManagerApi alarms = const AndroidAlarmManagerApi(),
  TargetPlatform? platform,
}) async {
  final isAndroid = (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  final timeZone = await _guard(initializeTimeZone, 'time zone');
  final notifications = await _guard(
    () => initializeReminderNotifications(
      container.read(flutterLocalNotificationsProvider),
    ),
    'notifications',
  );
  final alarmService =
      isAndroid ? await _guard(alarms.initialize, 'alarm manager') : false;

  // Restored even when a step above failed: a scheduled-notification fallback
  // still works without the alarm service, and a reminder that cannot notify
  // is cleared rather than left half-armed.
  final restored = await _guard(() async {
    await container.read(hydrationReminderControllerProvider).restoreSchedule();
    await container.read(mindfulnessReminderControllerProvider).restoreSchedule();
    return true;
  }, 'reminder schedules');

  return ReminderBootstrapResult(
    timeZoneReady: timeZone,
    notificationsReady: notifications,
    alarmServiceReady: alarmService,
    schedulesRestored: restored,
  );
}

Future<bool> _guard(Future<bool> Function() step, String label) async {
  try {
    return await step();
  } catch (error) {
    debugPrint('Reminder bootstrap: $label failed: $error');
    return false;
  }
}

class ReminderBootstrapResult {
  const ReminderBootstrapResult({
    required this.timeZoneReady,
    required this.notificationsReady,
    required this.alarmServiceReady,
    required this.schedulesRestored,
  });

  final bool timeZoneReady;
  final bool notificationsReady;

  /// Always false off Android, where there is no alarm manager to start.
  final bool alarmServiceReady;
  final bool schedulesRestored;
}
