import '../../../core/time/local_date.dart';
import '../../../data/prefs/preferences_repository.dart';
import '../../../data/repository/contract/hydration_repository.dart';
import '../../../domain/model/hydration_reminder_config.dart';
import 'hydration_reminder_schedule.dart';

/// Schedules the OS-level alarm that wakes the app to fire the next hydration
/// reminder. Device-specific; the concrete implementation
/// ([HydrationReminderDeviceScheduler]) wraps a plugin and is kept out of this
/// controller so the orchestration logic stays testable.
abstract interface class HydrationReminderScheduler {
  Future<void> schedule(DateTime triggerAt);

  Future<void> cancel();
}

/// Posts / clears the hydration reminder notification. Device-specific.
abstract interface class HydrationReminderNotifier {
  Future<void> showHydrationReminder(
    double currentLiters,
    double dailyGoalLiters,
  );

  Future<void> cancelReminderNotification();
}

/// Orchestrates hydration reminders, ported from the Kotlin
/// `HydrationReminderController`.
///
/// The pure scheduling math lives in [calculateNextHydrationReminderTime]; this
/// class wires it to persisted config ([PreferencesRepository]), today's intake
/// ([HydrationRepository]) and the device [HydrationReminderScheduler] /
/// [HydrationReminderNotifier]. Because those device seams are injected
/// interfaces, the whole controller is unit-testable with fakes.
class HydrationReminderController {
  HydrationReminderController({
    required this.preferences,
    required this.hydrationRepository,
    required this.notifier,
    required this.scheduler,
    this.now = DateTime.now,
    this.hasNotificationPermission = _permissionGranted,
  });

  final PreferencesRepository preferences;
  final HydrationRepository hydrationRepository;
  final HydrationReminderNotifier notifier;
  final HydrationReminderScheduler scheduler;
  final DateTime Function() now;
  final bool Function() hasNotificationPermission;

  HydrationReminderConfig config() => preferences.hydrationReminderConfig();

  /// Persists [config] and (re)applies the schedule.
  Future<void> updateConfig(HydrationReminderConfig config) async {
    final normalized = config.normalized();
    preferences.setHydrationReminderConfig(normalized);
    await applyConfig(normalized);
  }

  /// (Re)computes the next reminder from [config] (or the persisted config) and
  /// arms the scheduler, or clears everything when disabled / permission-less.
  Future<void> applyConfig([HydrationReminderConfig? config]) async {
    final normalized =
        (config ?? preferences.hydrationReminderConfig()).normalized();
    if (!normalized.enabled || !hasNotificationPermission()) {
      await _clearReminder();
      return;
    }
    await _scheduleNextReminder(
      normalized,
      dailyGoalMet: await _isDailyGoalMet(),
    );
  }

  /// Runs when an alarm fires: shows the reminder (unless the goal is met or the
  /// current time is outside the active window) and arms the next one.
  Future<void> handleReminderAlarm() async {
    final config = preferences.hydrationReminderConfig().normalized();
    if (!config.enabled || !hasNotificationPermission()) {
      await _clearReminder();
      return;
    }

    final currentLiters = await _todayHydrationLiters();
    final dailyGoalLiters = preferences.hydrationDailyGoalLiters;
    final goalMet = dailyGoalLiters > 0.0 && currentLiters >= dailyGoalLiters;
    final moment = now();
    final withinActiveHours = isWithinHydrationReminderActiveHours(
      LocalTime(moment.hour, moment.minute),
      config,
    );
    if (!goalMet && withinActiveHours) {
      await notifier.showHydrationReminder(currentLiters, dailyGoalLiters);
    }
    await _scheduleNextReminder(config, dailyGoalMet: goalMet);
  }

  /// Re-arms (or clears) the schedule, e.g. after a device reboot.
  Future<void> restoreSchedule() async {
    final config = preferences.hydrationReminderConfig();
    if (config.enabled) {
      await applyConfig(config);
    } else {
      await _clearReminder();
    }
  }

  Future<void> hideReminderNotification() =>
      notifier.cancelReminderNotification();

  Future<bool> _isDailyGoalMet() async {
    final dailyGoalLiters = preferences.hydrationDailyGoalLiters;
    return dailyGoalLiters > 0.0 &&
        await _todayHydrationLiters() >= dailyGoalLiters;
  }

  Future<double> _todayHydrationLiters() async {
    final today = LocalDate.now();
    try {
      final daily = await hydrationRepository.loadDailyHydration(today, today);
      return daily.fold<double>(0.0, (sum, day) => sum + day.liters);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _scheduleNextReminder(
    HydrationReminderConfig config, {
    required bool dailyGoalMet,
  }) async {
    final triggerAt = calculateNextHydrationReminderTime(
      now(),
      config,
      dailyGoalMet: dailyGoalMet,
    );
    await scheduler.schedule(triggerAt);
  }

  Future<void> _clearReminder() async {
    await scheduler.cancel();
    await notifier.cancelReminderNotification();
  }
}

/// Default permission gate. On-device the Android 13+ POST_NOTIFICATIONS check
/// is wired in via the injected callback; the pure default assumes granted so
/// tests and non-Android targets behave predictably.
bool _permissionGranted() => true;
