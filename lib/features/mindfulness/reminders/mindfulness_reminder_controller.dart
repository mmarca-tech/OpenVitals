import '../../../core/time/local_date.dart';
import '../../../data/prefs/preferences_repository.dart';
import '../../../data/repository/contract/mindfulness_repository.dart';
import '../../../domain/insights/daily_goals.dart';
import '../../../domain/model/mindfulness_reminder_config.dart';
import 'mindfulness_reminder_schedule.dart';

/// Schedules the OS-level alarm for the next mindfulness reminder.
/// Device-specific; kept behind an interface so the controller stays testable.
abstract interface class MindfulnessReminderScheduler {
  Future<void> schedule(DateTime triggerAt);

  Future<void> cancel();
}

/// Posts / clears the mindfulness reminder notification. Device-specific.
abstract interface class MindfulnessReminderNotifier {
  Future<void> showMindfulnessReminder(
    double currentMinutes,
    double dailyGoalMinutes,
  );

  Future<void> cancelReminderNotification();
}

/// Orchestrates the daily mindfulness reminder, ported from the Kotlin
/// `MindfulnessReminderController`. Pure scheduling math lives in
/// [calculateNextMindfulnessReminderTime]; device seams are injected.
class MindfulnessReminderController {
  MindfulnessReminderController({
    required this.preferences,
    required this.mindfulnessRepository,
    required this.notifier,
    required this.scheduler,
    this.now = DateTime.now,
    this.hasNotificationPermission = _permissionGranted,
  });

  final PreferencesRepository preferences;
  final MindfulnessRepository mindfulnessRepository;
  final MindfulnessReminderNotifier notifier;
  final MindfulnessReminderScheduler scheduler;
  final DateTime Function() now;
  final bool Function() hasNotificationPermission;

  static const double _millisPerMinute = 60000.0;

  MindfulnessReminderConfig config() => preferences.mindfulnessReminderConfig();

  Future<void> updateConfig(MindfulnessReminderConfig config) async {
    final normalized = config.normalized();
    preferences.setMindfulnessReminderConfig(normalized);
    await applyConfig(normalized);
  }

  Future<void> applyConfig([MindfulnessReminderConfig? config]) async {
    final normalized =
        (config ?? preferences.mindfulnessReminderConfig()).normalized();
    if (!normalized.enabled || !hasNotificationPermission()) {
      await _clearReminder();
      return;
    }
    await _scheduleNextReminder(
      normalized,
      dailyGoalMet: await _isDailyGoalMet(),
    );
  }

  Future<void> handleReminderAlarm() async {
    final config = preferences.mindfulnessReminderConfig().normalized();
    if (!config.enabled || !hasNotificationPermission()) {
      await _clearReminder();
      return;
    }

    final currentMinutes = await _todayMindfulnessMinutes();
    final dailyGoalMinutes =
        preferences.dailyGoalFor(MetricDailyGoalKey.mindfulnessMinutes);
    final goalMet = dailyGoalMinutes > 0.0 && currentMinutes >= dailyGoalMinutes;
    if (!goalMet) {
      await notifier.showMindfulnessReminder(currentMinutes, dailyGoalMinutes);
    }
    await _scheduleNextReminder(config, dailyGoalMet: goalMet);
  }

  Future<void> restoreSchedule() async {
    final config = preferences.mindfulnessReminderConfig();
    if (config.enabled) {
      await applyConfig(config);
    } else {
      await _clearReminder();
    }
  }

  Future<void> hideReminderNotification() =>
      notifier.cancelReminderNotification();

  Future<bool> _isDailyGoalMet() async {
    final dailyGoalMinutes =
        preferences.dailyGoalFor(MetricDailyGoalKey.mindfulnessMinutes);
    return dailyGoalMinutes > 0.0 &&
        await _todayMindfulnessMinutes() >= dailyGoalMinutes;
  }

  Future<double> _todayMindfulnessMinutes() async {
    final today = LocalDate.now();
    try {
      final sessions =
          await mindfulnessRepository.loadMindfulnessSessions(today, today);
      final totalMs = sessions.fold<int>(
        0,
        (sum, session) => sum + (session.durationMs < 0 ? 0 : session.durationMs),
      );
      return totalMs / _millisPerMinute;
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _scheduleNextReminder(
    MindfulnessReminderConfig config, {
    required bool dailyGoalMet,
  }) async {
    final triggerAt = calculateNextMindfulnessReminderTime(
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

bool _permissionGranted() => true;
