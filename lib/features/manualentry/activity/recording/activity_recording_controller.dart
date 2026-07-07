import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../../data/prefs/preferences_repository.dart';
import '../../../../domain/model/activity_models.dart';
import '../../../../domain/model/ble_sensor_models.dart';
import '../../../../domain/preferences/activity_recording_dashboard_layout.dart';
import '../../../../domain/preferences/activity_recording_preferences.dart';
import '../../../../sensors/ble/ble_sensor_coordinator.dart';
import '../activity_entry_types.dart';
import '../repetition_recognizers.dart';
import 'activity_recording.dart';
import 'activity_recording_serialization.dart';
import 'activity_recording_splits.dart';

/// Device-bound port of the Kotlin `ActivityRecordingController` +
/// `ActivityRecordingService`, wiring GPS ([Geolocator]), motion/barometer
/// ([sensors_plus]), the foreground service ([flutter_foreground_task]),
/// notifications ([flutter_local_notifications]) and voice announcements
/// ([flutter_tts]) onto the pure [ActivityRecordingState] model.
///
/// The pure state transitions (distance/pace/elevation accumulation, pause /
/// rest / repetition bookkeeping, snapshot building) are shared with the tested
/// model helpers. The device I/O is best-effort and intentionally deferred from
/// unit testing — only compile-cleanliness is required here.
class ActivityRecordingControllerImpl implements ActivityRecordingController {
  ActivityRecordingControllerImpl({
    required this.preferencesRepository,
    required this.bleSensorCoordinator,
    required this.recordingStore,
  }) {
    _state = ValueNotifier<ActivityRecordingState>(recordingStore.restore());
    _bleSub =
        bleSensorCoordinator.metricsStream.listen(acceptBleMetrics);
    _scheduleRestCompletion(_state.value);
  }

  final PreferencesRepository preferencesRepository;
  final BleSensorCoordinator bleSensorCoordinator;
  final ActivityRecordingStore recordingStore;

  late final ValueNotifier<ActivityRecordingState> _state;
  @override
  ValueListenable<ActivityRecordingState> get state => _state;

  final FlutterTts _tts = FlutterTts();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BarometerEvent>? _barometerSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<BleRecordingMetrics>? _bleSub;
  Timer? _restCompletionTimer;
  int _recordingGeneration = 0;
  JumpRepetitionRecognizer? _jumpRecognizer;
  PullUpRepetitionRecognizer? _pullRecognizer;

  void dispose() {
    _positionSub?.cancel();
    _barometerSub?.cancel();
    _accelSub?.cancel();
    _bleSub?.cancel();
    _restCompletionTimer?.cancel();
    _state.dispose();
  }

  // ── Preparation ──────────────────────────────────────────────────────────

  @override
  void prepareRecordingDashboard(ActivityEntryType activityType) {
    if (_state.value.isActive) return;
    _recordingGeneration += 1;
    _updateAndPersist(
      ActivityRecordingState(
        status: ActivityRecordingStatus.idle,
        recordingKind: _recordingKind(activityType),
        activityTypeId: activityType.id,
        exerciseType: activityType.exerciseType,
        dashboardLayout: preferencesRepository
            .activityRecordingDashboardLayout(activityType.id),
      ),
    );
    previewBleConnections();
  }

  @override
  void updateDashboardLayout(ActivityRecordingDashboardLayout layout) {
    final current = _state.value;
    final activityTypeId = current.activityTypeId;
    if (activityTypeId == null) return;
    if (current.status == ActivityRecordingStatus.recording) return;
    final normalized = layout.normalized();
    preferencesRepository.setActivityRecordingDashboardLayout(
        activityTypeId, normalized);
    _updateAndPersist(
        current.copyWith(dashboardLayout: normalized, errorMessage: null));
  }

  @override
  void clearPreparedRecording() {
    if (_state.value.isActive) return;
    _clearRecording();
  }

  @override
  void previewBleConnections() {
    if (_state.value.isActive) return;
    bleSensorCoordinator.refreshConnections();
    acceptBleMetrics(bleSensorCoordinator.metrics);
  }

  @override
  void stopBlePreview() {
    if (_state.value.isActive) return;
    bleSensorCoordinator.disconnectAll();
  }

  // ── Start ────────────────────────────────────────────────────────────────

  @override
  bool startRecording(
    ActivityEntryType activityType,
    ActivityRecordingInitialFix? initialFix, {
    int repetitionRestSeconds = 0,
  }) {
    if (activityType.supportsGpsRoute) {
      return _startGpsRecording(activityType, initialFix);
    }
    if (activityType.isRepetitionLike) {
      return _startRepetitionRecording(activityType, repetitionRestSeconds);
    }
    if (activityType.recordingSensor == ActivityRecordingSensor.ble) {
      return _startTimedRecording(activityType);
    }
    _updateAndPersist(_state.value
        .copyWith(errorMessage: 'This activity type cannot be recorded live.'));
    return false;
  }

  bool _startGpsRecording(
      ActivityEntryType activityType, ActivityRecordingInitialFix? initialFix) {
    final preferences = preferencesRepository.activityRecordingPreferences();
    final dashboardLayout =
        preferencesRepository.activityRecordingDashboardLayout(activityType.id);
    final now = DateTime.now().toUtc();
    if (initialFix == null) {
      _updateAndPersist(_state.value
          .copyWith(errorMessage: 'Waiting for a precise GPS fix.'));
      return false;
    }
    _recordingGeneration += 1;
    _updateAndPersist(
      ActivityRecordingState(
        status: ActivityRecordingStatus.recording,
        recordingKind: ActivityRecordingKind.gpsRoute,
        activityTypeId: activityType.id,
        exerciseType: activityType.exerciseType,
        startTime: now,
        gpsStatus: ActivityGpsStatus.fix,
        keepScreenOnDuringRecording: preferences.keepScreenOnDuringRecording,
        autoIdleEnabled: preferences.autoIdleEnabled,
        autoIdleTimeoutMillis: preferences.autoIdleTimeoutSeconds * 1000,
        lastMovementAt: now,
        lastAccuracyMeters: initialFix.accuracyMeters,
        lastLocationTime: now,
        dashboardLayout: dashboardLayout,
      ),
    );
    _startLocationUpdates(preferences);
    _startBarometerUpdates(preferences);
    bleSensorCoordinator.startRecording();
    acceptBleMetrics(bleSensorCoordinator.metrics);
    _startForegroundService(activityType.label);
    return true;
  }

  bool _startRepetitionRecording(
      ActivityEntryType activityType, int repetitionRestSeconds) {
    final preferences = preferencesRepository.activityRecordingPreferences();
    final dashboardLayout =
        preferencesRepository.activityRecordingDashboardLayout(activityType.id);
    final now = DateTime.now().toUtc();
    _recordingGeneration += 1;
    _updateAndPersist(
      ActivityRecordingState(
        status: ActivityRecordingStatus.recording,
        recordingKind: ActivityRecordingKind.repetition,
        activityTypeId: activityType.id,
        exerciseType: activityType.exerciseType,
        startTime: now,
        keepScreenOnDuringRecording: preferences.keepScreenOnDuringRecording,
        currentSetStartedAt: now,
        repetitionRestSeconds:
            repetitionRestSeconds < 0 ? 0 : repetitionRestSeconds,
        dashboardLayout: dashboardLayout,
      ),
    );
    _startMotionRecognizer(activityType);
    bleSensorCoordinator.startRecording();
    acceptBleMetrics(bleSensorCoordinator.metrics);
    _startForegroundService(activityType.label);
    return true;
  }

  bool _startTimedRecording(ActivityEntryType activityType) {
    final preferences = preferencesRepository.activityRecordingPreferences();
    final dashboardLayout =
        preferencesRepository.activityRecordingDashboardLayout(activityType.id);
    final now = DateTime.now().toUtc();
    _recordingGeneration += 1;
    _updateAndPersist(
      ActivityRecordingState(
        status: ActivityRecordingStatus.recording,
        recordingKind: ActivityRecordingKind.timed,
        activityTypeId: activityType.id,
        exerciseType: activityType.exerciseType,
        startTime: now,
        keepScreenOnDuringRecording: preferences.keepScreenOnDuringRecording,
        dashboardLayout: dashboardLayout,
      ),
    );
    bleSensorCoordinator.startRecording();
    acceptBleMetrics(bleSensorCoordinator.metrics);
    _startForegroundService(activityType.label);
    return true;
  }

  // ── BLE ──────────────────────────────────────────────────────────────────

  void acceptBleMetrics(BleRecordingMetrics metrics) {
    final current = _state.value;
    _updateAndPersist(
      current.copyWith(
        currentHeartRateBpm: metrics.heartRateBpm,
        currentCyclingCadenceRpm: metrics.cyclingCadenceRpm,
        currentPowerWatts: metrics.powerWatts,
        currentSensorSpeedMetersPerSecond: metrics.cyclingSpeedMetersPerSecond ??
            metrics.runningSpeedMetersPerSecond,
        currentRunningCadenceRpm: metrics.runningCadenceRpm,
        bleHeartRateNoSignal:
            metrics.heartRateNoSignal && metrics.heartRateBpm == null,
        bleDeviceStatuses: metrics.deviceStatuses.isEmpty
            ? current.bleDeviceStatuses
            : metrics.deviceStatuses,
      ),
    );
  }

  // ── Pause / resume ─────────────────────────────────────────────────────────

  @override
  void pauseRecording() {
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.recording) return;
    _updateAndPersist(current.copyWith(
      status: ActivityRecordingStatus.paused,
      pausedStartedAt: DateTime.now().toUtc(),
      errorMessage: null,
    ));
  }

  @override
  void resumeRecording() {
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.paused) return;
    final now = DateTime.now().toUtc();
    final pausedStart = current.pausedStartedAt;
    final pausedMillis = pausedStart == null
        ? 0
        : (now.millisecondsSinceEpoch - pausedStart.millisecondsSinceEpoch)
            .clamp(0, 1 << 62);
    final closedPause =
        pausedStart == null ? null : toPauseInterval(pausedStart, now);
    _updateAndPersist(current.copyWith(
      status: ActivityRecordingStatus.recording,
      pausedStartedAt: null,
      totalPausedMillis: current.totalPausedMillis + pausedMillis,
      pauseIntervals: [...current.pauseIntervals, ?closedPause],
      errorMessage: null,
    ));
  }

  // ── Laps / markers ─────────────────────────────────────────────────────────

  @override
  void addManualLap() {
    final current = _state.value;
    if (!current.isActive ||
        current.recordingKind != ActivityRecordingKind.gpsRoute) {
      return;
    }
    final start = current.manualLaps.isNotEmpty
        ? current.manualLaps
            .reduce((a, b) => a.endTime.isAfter(b.endTime) ? a : b)
            .endTime
        : current.startTime;
    if (start == null) return;
    final end = DateTime.now().toUtc();
    if (!start.isBefore(end)) return;
    final distance = activityRecordingRouteDistanceMeters(
      points: current.points,
      routeBreakIndexes: current.routeBreakIndexes,
      startTime: start,
      endTime: end,
    );
    _updateAndPersist(current.copyWith(
      manualLaps: [
        ...current.manualLaps,
        ActivityRecordingLap(
          startTime: start,
          endTime: end,
          distanceMeters: distance > 0.0 ? distance : null,
        ),
      ],
      errorMessage: null,
    ));
  }

  @override
  void addMarker() {
    final current = _state.value;
    if (!current.isActive ||
        current.recordingKind != ActivityRecordingKind.gpsRoute) {
      return;
    }
    final point = current.latestUiPoint ??
        (current.points.isNotEmpty ? current.points.last : null);
    if (point == null) return;
    final markerNumber = current.markers.length + 1;
    _updateAndPersist(current.copyWith(
      markers: [
        ...current.markers,
        ActivityRecordingMarker(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          time: point.time,
          latitude: point.latitude,
          longitude: point.longitude,
          altitudeMeters: point.altitudeMeters,
          name: 'Marker $markerNumber',
          type: ActivityRecordingMarkerType.generic.value,
        ),
      ],
      errorMessage: null,
    ));
  }

  @override
  void updateMarker(ActivityRecordingMarker marker) {
    final current = _state.value;
    if (!current.isActive ||
        current.recordingKind != ActivityRecordingKind.gpsRoute) {
      return;
    }
    _updateAndPersist(current.copyWith(
      markers: [
        for (final existing in current.markers)
          existing.id == marker.id ? marker : existing,
      ],
      errorMessage: null,
    ));
  }

  @override
  void deleteMarker(String markerId) {
    final current = _state.value;
    if (!current.isActive ||
        current.recordingKind != ActivityRecordingKind.gpsRoute) {
      return;
    }
    _updateAndPersist(current.copyWith(
      markers: current.markers.where((m) => m.id != markerId).toList(),
      errorMessage: null,
    ));
  }

  // ── Discard / finish ───────────────────────────────────────────────────────

  @override
  void discardRecording() {
    bleSensorCoordinator.stopRecording();
    _clearRecording();
    _stopForegroundService();
  }

  @override
  ActivityRecordingSnapshot? finishRecording() {
    final current = _state.value;
    final start = current.startTime;
    final exerciseType = current.exerciseType;
    if (start == null || exerciseType == null || !current.isActive) return null;

    final nowCandidate = DateTime.now().toUtc();
    final end = nowCandidate.isAfter(start)
        ? nowCandidate
        : start.add(const Duration(seconds: 1));
    final pauseIntervals = [
      ...current.pauseIntervals,
      ?(current.pausedStartedAt == null
          ? null
          : toPauseInterval(current.pausedStartedAt!, end)),
    ];
    final manualLaps = current.closedManualLaps(end);
    final repetitionSets = current.recordedRepetitionSets(end);
    final bleSamples = bleSensorCoordinator.stopRecording();
    final snapshot = ActivityRecordingSnapshot(
      exerciseType: exerciseType,
      recordingKind: current.recordingKind,
      activityTypeId: current.activityTypeId,
      startTime: start,
      endTime: end,
      points: current.points,
      pauseIntervals: pauseIntervals,
      routeBreakIndexes: current.routeBreakIndexes,
      manualLaps: manualLaps,
      markers: current.markers,
      distanceMeters: current.distanceMeters,
      elevationGainedMeters: current.hasBarometerElevation
          ? current.barometerElevationGainedMeters
          : current.elevationGainedMeters,
      repetitionCount: current.repetitionCount,
      repetitionSets: repetitionSets,
      bleSamples: bleSamples,
    );
    _clearRecording();
    _stopForegroundService();
    return snapshot;
  }

  // ── Repetition counting ──────────────────────────────────────────────────

  @override
  void adjustRepetitionCount(int delta) {
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.recording) return;
    if (current.recordingKind == ActivityRecordingKind.gpsRoute) {
      if (activityEntryTypeById(current.activityTypeId)?.supportsStepCounting !=
          true) {
        return;
      }
      final nextCount = (current.repetitionCount + delta).clamp(0, 1 << 62);
      _updateAndPersist(current.copyWith(
        currentSetRepetitionCount: nextCount,
        repetitionCount: nextCount,
        errorMessage: null,
      ));
      return;
    }
    if (current.recordingKind != ActivityRecordingKind.repetition) return;
    final nextCurrentSetCount =
        (current.currentSetRepetitionCount + delta).clamp(0, 1 << 62);
    final completedCount =
        current.repetitionSets.fold<int>(0, (sum, s) => sum + s.repetitions);
    _updateAndPersist(current.copyWith(
      currentSetRepetitionCount: nextCurrentSetCount,
      repetitionCount: completedCount + nextCurrentSetCount,
      errorMessage: null,
    ));
  }

  @override
  void endRepetitionSet() {
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.recording ||
        current.recordingKind != ActivityRecordingKind.repetition ||
        current.currentSetRepetitionCount <= 0) {
      return;
    }
    final now = DateTime.now().toUtc();
    final activeMillis = (now.millisecondsSinceEpoch -
            (current.currentSetStartedAt ?? current.startTime ?? now)
                .millisecondsSinceEpoch)
        .clamp(1, 1 << 62);
    final completedSet = ActivityRecordedRepetitionSet(
      repetitions: current.currentSetRepetitionCount,
      restSeconds: current.repetitionRestSeconds,
      activeMillis: activeMillis,
    );
    final ActivityRecordingState next;
    if (current.repetitionRestSeconds > 0) {
      next = current.copyWith(
        status: ActivityRecordingStatus.resting,
        repetitionSets: [...current.repetitionSets, completedSet],
        currentSetRepetitionCount: 0,
        restStartedAt: now,
        currentSetStartedAt: null,
        errorMessage: null,
      );
    } else {
      next = current.copyWith(
        repetitionSets: [...current.repetitionSets, completedSet],
        currentSetRepetitionCount: 0,
        currentSetStartedAt: now,
        errorMessage: null,
      );
    }
    _updateAndPersist(next);
  }

  @override
  void startNextRepetitionSet() {
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.resting ||
        current.recordingKind != ActivityRecordingKind.repetition) {
      return;
    }
    _startNextRepetitionSet(current, DateTime.now().toUtc());
  }

  void _startNextRepetitionSet(ActivityRecordingState current, DateTime now) {
    final actualRestMillis = current.openRestMillis(now);
    final updatedSets = withLastRestSeconds(
        current.repetitionSets, (actualRestMillis ~/ 1000).clamp(0, 1 << 62));
    _updateAndPersist(current.copyWith(
      status: ActivityRecordingStatus.recording,
      repetitionSets: updatedSets,
      accumulatedRestMillis: current.accumulatedRestMillis + actualRestMillis,
      restStartedAt: null,
      currentSetStartedAt: now,
      errorMessage: null,
    ));
  }

  // ── Location processing ────────────────────────────────────────────────────

  void _startLocationUpdates(ActivityRecordingPreferences preferences) {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: preferences.recordingDistanceIntervalMeters ?? 0,
      ),
    ).listen(_acceptPosition, onError: (Object _) {});
  }

  void _acceptPosition(Position position) {
    final generation = _recordingGeneration;
    if (generation != _recordingGeneration) return;
    final preferences = preferencesRepository.activityRecordingPreferences();
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.recording) return;
    if (current.recordingKind != ActivityRecordingKind.gpsRoute) return;

    final accuracy = position.accuracy;
    final locationTime = position.timestamp.toUtc();
    final requiredAccuracy = preferences.requiredGpsAccuracyMeters.toDouble();
    final isPrecise = accuracy <= requiredAccuracy;
    final point = _toRoutePoint(position, locationTime);

    if (!isPrecise) {
      _updateAndPersist(
        withDroppedLocation(
          current,
          accuracy,
          locationTime: locationTime,
          gpsStatus: ActivityGpsStatus.poorAccuracy,
        ).copyWith(latestUiPoint: point),
      );
      return;
    }

    final lastPoint = current.points.isNotEmpty ? current.points.last : null;
    var distanceIncrement = 0.0;
    var elevationIncrement = 0.0;
    var elevationLossIncrement = 0.0;
    var currentSpeed = 0.0;
    var routeBreakIndexes = current.routeBreakIndexes;
    var lastMovementAt = current.lastMovementAt ?? current.startTime ?? point.time;
    var totalIdleMillis = current.totalIdleMillis;

    if (lastPoint != null) {
      if (!point.time.isAfter(lastPoint.time)) {
        _updateAndPersist(withDroppedLocation(current, accuracy,
            locationTime: point.time, gpsStatus: ActivityGpsStatus.fix));
        return;
      }
      final elapsedMillis = (point.time.millisecondsSinceEpoch -
              lastPoint.time.millisecondsSinceEpoch)
          .clamp(0, 1 << 62);
      final distanceMeters = recordingDistanceMetersTo(lastPoint, point);
      if (distanceMeters < current.minimumSampleDistanceMeters(preferences) ||
          elapsedMillis < preferences.recordingTimeIntervalMillis) {
        _updateAndPersist(
          withLocationMetadata(
            current,
            accuracyMeters: accuracy,
            locationTime: point.time,
            gpsStatus: ActivityGpsStatus.fix,
            recordingPreferences: preferences,
          ).copyWith(latestUiPoint: point),
        );
        return;
      }
      final routeGap = preferences.routeGapMeters;
      final startsNewSegment = routeGap != null && distanceMeters > routeGap;
      if (startsNewSegment) {
        routeBreakIndexes = [...routeBreakIndexes, current.points.length];
      } else {
        if (isImplausibleJump(
            lastPoint, point, distanceMeters, elapsedMillis, accuracy)) {
          _updateAndPersist(withDroppedLocation(current, accuracy,
              locationTime: point.time, gpsStatus: ActivityGpsStatus.fix));
          return;
        }
        distanceIncrement = distanceMeters;
        elevationIncrement = elevationGainMetersTo(lastPoint, point);
        elevationLossIncrement = elevationLossMetersTo(lastPoint, point);
        currentSpeed = distanceMeters / (elapsedMillis / 1000.0);
        if (current.autoIdleEnabled) {
          final idleStartedAt = lastMovementAt
              .add(Duration(milliseconds: current.autoIdleTimeoutMillis));
          if (point.time.isAfter(idleStartedAt)) {
            totalIdleMillis += (point.time.millisecondsSinceEpoch -
                    idleStartedAt.millisecondsSinceEpoch)
                .clamp(0, 1 << 62);
          }
        }
        lastMovementAt = point.time;
      }
    }

    _updateAndPersist(
      current.copyWith(
        points: [...current.points, point],
        routeBreakIndexes: routeBreakIndexes,
        latestUiPoint: point,
        distanceMeters: current.distanceMeters + distanceIncrement,
        elevationGainedMeters: current.elevationGainedMeters + elevationIncrement,
        elevationLostMeters: current.elevationLostMeters + elevationLossIncrement,
        currentSpeedMetersPerSecond: currentSpeed,
        maxSpeedMetersPerSecond:
            current.maxSpeedMetersPerSecond > currentSpeed
                ? current.maxSpeedMetersPerSecond
                : currentSpeed,
        gpsStatus: ActivityGpsStatus.fix,
        keepScreenOnDuringRecording: preferences.keepScreenOnDuringRecording,
        autoIdleEnabled: preferences.autoIdleEnabled,
        autoIdleTimeoutMillis: preferences.autoIdleTimeoutSeconds * 1000,
        lastMovementAt: lastMovementAt,
        totalIdleMillis: totalIdleMillis,
        lastAccuracyMeters: accuracy,
        lastLocationTime: point.time,
        errorMessage: null,
      ),
    );
    _maybeAnnounce(current);
  }

  ExerciseRoutePoint _toRoutePoint(Position position, DateTime time) =>
      ExerciseRoutePoint(
        time: time,
        latitude: position.latitude,
        longitude: position.longitude,
        altitudeMeters: position.altitude == 0.0 ? null : position.altitude,
        horizontalAccuracyMeters: position.accuracy,
        verticalAccuracyMeters:
            position.altitudeAccuracy == 0.0 ? null : position.altitudeAccuracy,
      );

  // ── Barometer ──────────────────────────────────────────────────────────────

  void _startBarometerUpdates(ActivityRecordingPreferences preferences) {
    if (!preferences.barometerClimbEnabled) return;
    _barometerSub?.cancel();
    _barometerSub = barometerEventStream()
        .listen((event) => acceptBarometerPressure(event.pressure),
            onError: (Object _) {});
  }

  void acceptBarometerPressure(double pressureHpa) {
    final current = _state.value;
    if (current.status != ActivityRecordingStatus.recording ||
        current.recordingKind != ActivityRecordingKind.gpsRoute) {
      return;
    }
    if (!preferencesRepository
        .activityRecordingPreferences()
        .barometerClimbEnabled) {
      return;
    }
    // Barometric altitude via the international barometric formula.
    const seaLevelHpa = 1013.25;
    final altitudeMeters = 44330.0 *
        (1.0 - math.pow(pressureHpa / seaLevelHpa, 0.1902949).toDouble());
    final previous = current.lastBarometerAltitudeMeters;
    final smoothed = previous == null
        ? altitudeMeters
        : previous + (altitudeMeters - previous) * barometerSmoothingAlpha;
    if (previous == null) {
      _updateAndPersist(current.copyWith(
        hasBarometerElevation: true,
        lastBarometerAltitudeMeters: smoothed,
      ));
      return;
    }
    final delta = smoothed - previous;
    final gained = delta >= minBarometerElevationStepMeters ? delta : 0.0;
    final lost = delta <= -minBarometerElevationStepMeters ? -delta : 0.0;
    _updateAndPersist(current.copyWith(
      hasBarometerElevation: true,
      barometerElevationGainedMeters:
          current.barometerElevationGainedMeters + gained,
      barometerElevationLostMeters: current.barometerElevationLostMeters + lost,
      lastBarometerAltitudeMeters: (gained > 0.0 || lost > 0.0) ? smoothed : previous,
    ));
  }

  // ── Motion recognizers (repetition sensors) ──────────────────────────────

  void _startMotionRecognizer(ActivityEntryType activityType) {
    _jumpRecognizer = null;
    _pullRecognizer = null;
    if (activityType.recordingSensor != ActivityRecordingSensor.accelerometer) {
      // Proximity + step-detector sensors are not exposed by sensors_plus; those
      // recording kinds fall back to manual counting.
      return;
    }
    if (activityType.segmentType == ExerciseSegmentType.pullUp) {
      _pullRecognizer = PullUpRepetitionRecognizer();
    } else {
      _jumpRecognizer = JumpRepetitionRecognizer(maxJumpDurationMillis: 1250);
    }
    _accelSub?.cancel();
    _accelSub = accelerometerEventStream().listen(_acceptAcceleration,
        onError: (Object _) {});
  }

  void _acceptAcceleration(AccelerometerEvent event) {
    if (_state.value.status != ActivityRecordingStatus.recording) return;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final recognized = _pullRecognizer?.onAcceleration(
          event.x,
          event.y,
          event.z,
          nowMillis,
        ) ??
        _jumpRecognizer?.onAcceleration(event.x, event.y, event.z, nowMillis);
    if (recognized != null) adjustRepetitionCount(1);
  }

  // ── Voice announcements (best effort) ───────────────────────────────────────

  DateTime? _lastAnnouncementAt;

  void _maybeAnnounce(ActivityRecordingState previous) {
    final preferences = preferencesRepository.activityRecordingPreferences();
    if (!preferences.voiceAnnouncementsEnabled) return;
    final interval = preferences.voiceAnnouncementTimeIntervalMinutes;
    if (interval == null) return;
    final now = DateTime.now().toUtc();
    final last = _lastAnnouncementAt;
    if (last != null && now.difference(last).inMinutes < interval) return;
    _lastAnnouncementAt = now;
    final distanceKm = (_state.value.distanceMeters / 1000.0).toStringAsFixed(1);
    unawaited(_speak('Distance $distanceKm kilometers.'));
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (_) {
      // Voice output is best-effort.
    }
  }

  // ── Foreground service + notification ────────────────────────────────────

  void _startForegroundService(String activityLabel) {
    unawaited(() async {
      try {
        await _notifications.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(),
          ),
        );
        await FlutterForegroundTask.startService(
          notificationTitle: 'Recording $activityLabel',
          notificationText: 'OpenVitals is recording your activity.',
        );
      } catch (_) {
        // Foreground service is best-effort in this batch.
      }
    }());
  }

  void _stopForegroundService() {
    unawaited(() async {
      try {
        await FlutterForegroundTask.stopService();
        await _notifications.cancelAll();
      } catch (_) {
        // Best-effort.
      }
    }());
  }

  // ── Rest-completion timer ────────────────────────────────────────────────

  void _scheduleRestCompletion(ActivityRecordingState state) {
    _restCompletionTimer?.cancel();
    _restCompletionTimer = null;
    final restEnd = state.restEndTime();
    if (restEnd == null) return;
    final now = DateTime.now().toUtc();
    final delayMillis =
        (restEnd.millisecondsSinceEpoch - now.millisecondsSinceEpoch)
            .clamp(0, 1 << 62);
    _restCompletionTimer = Timer(Duration(milliseconds: delayMillis), () {
      final current = _state.value;
      if (current.status == ActivityRecordingStatus.resting &&
          current.restStartedAt == state.restStartedAt) {
        _restCompletionTimer = null;
        if (preferencesRepository
            .activityRecordingPreferences()
            .restTimerBellEnabled) {
          unawaited(_speak('Rest complete.'));
        }
        _startNextRepetitionSet(current, DateTime.now().toUtc());
      }
    });
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  void _clearRecording() {
    _positionSub?.cancel();
    _barometerSub?.cancel();
    _accelSub?.cancel();
    _restCompletionTimer?.cancel();
    _recordingGeneration += 1;
    _state.value = const ActivityRecordingState();
    unawaited(recordingStore.clear());
  }

  void _updateAndPersist(ActivityRecordingState state) {
    _state.value = state;
    unawaited(recordingStore.storeMetadata(state));
    _scheduleRestCompletion(state);
  }

  ActivityRecordingKind _recordingKind(ActivityEntryType activityType) {
    if (activityType.supportsGpsRoute) return ActivityRecordingKind.gpsRoute;
    if (activityType.isRepetitionLike) return ActivityRecordingKind.repetition;
    return ActivityRecordingKind.timed;
  }
}
