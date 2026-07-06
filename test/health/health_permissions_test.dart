import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:openvitals/domain/model/permission_grant_mode.dart';
import 'package:openvitals/health/health_permissions.dart';

void main() {
  const service = HealthPermissionService();

  group('phased permission sets', () {
    test('PERMISSION_SET_VERSION is 2', () {
      expect(HealthPermissionService.PERMISSION_SET_VERSION, 2);
    });

    test('phase1 == core == steps/distance/exercise/sleep reads', () {
      expect(service.phase1Permissions, service.corePermissions);
      expect(
        service.corePermissions,
        {
          HcPermissions.readSteps,
          HcPermissions.readDistance,
          HcPermissions.readExercise,
          HcPermissions.readSleep,
        },
      );
    });

    test('phase2 covers heart, body, activity-extras and nutrition/hydration', () {
      expect(service.phase2Permissions, containsAll(service.heartPermissions));
      expect(service.phase2Permissions, containsAll(service.bodyPermissions));
      expect(
        service.phase2Permissions,
        containsAll(service.nutritionHydrationPermissions),
      );
    });

    test('phase3 == vitals reads; phase4 == cycle reads', () {
      expect(service.phase3Permissions, service.vitalsPermissions);
      expect(service.phase4Permissions, service.cyclePermissions);
    });

    test('manual-only == route permissions and drives grant mode', () {
      expect(service.manualOnlyPermissions, service.routePermissions);
      expect(
        service.grantModeFor(HealthPermissionService.readExerciseRoutesPermission),
        PermissionGrantMode.manual,
      );
      expect(
        service.grantModeFor(HcPermissions.readSteps),
        PermissionGrantMode.requestable,
      );
    });

    test('managed permissions include reads, writes and route', () {
      final managed = service.managedPermissions;
      expect(managed, containsAll(service.corePermissions));
      expect(managed, containsAll(service.activityWritePermissions));
      expect(managed, containsAll(service.dataImportWritePermissions));
      expect(managed, contains(HealthPermissionService.readExerciseRoutesPermission));
    });
  });

  group('feature gating', () {
    test('mindfulness excluded from phase2 / requestable writes when unavailable',
        () {
      expect(
        service.phase2Permissions.contains(HcPermissions.readMindfulness),
        isFalse,
      );
      expect(
        service.requestableWritePermissions
            .contains(HcPermissions.writeMindfulness),
        isFalse,
      );
    });

    test('mindfulness included when the feature flag is set', () {
      const withMindfulness = HealthPermissionService(
        HealthConnectFeatureFlags(mindfulnessAvailable: true),
      );
      expect(
        withMindfulness.phase2Permissions.contains(HcPermissions.readMindfulness),
        isTrue,
      );
    });

    test('skin temperature gated on the feature flag', () {
      expect(service.vitalsPermissions.contains(HcPermissions.readSkinTemperature),
          isFalse);
      const withSkin = HealthPermissionService(
        HealthConnectFeatureFlags(skinTemperatureAvailable: true),
      );
      expect(
        withSkin.vitalsPermissions.contains(HcPermissions.readSkinTemperature),
        isTrue,
      );
    });
  });

  group('health package mapping', () {
    test('read/write records map to the right type + access', () {
      final steps = HealthPermissionService.mappingFor(HcPermissions.readSteps);
      expect(steps!.types, [HealthDataType.STEPS]);
      expect(steps.access, HealthDataAccess.READ);

      final water = HealthPermissionService.mappingFor(HcPermissions.writeHydration);
      expect(water!.types, [HealthDataType.WATER]);
      expect(water.access, HealthDataAccess.WRITE);
    });

    test('blood pressure expands to systolic + diastolic', () {
      final mapping =
          HealthPermissionService.mappingFor(HcPermissions.readBloodPressure);
      expect(mapping!.types, [
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ]);
    });

    test('unmappable records (documented gaps) resolve to null', () {
      expect(HealthPermissionService.mappingFor(HcPermissions.readBoneMass), isNull);
      expect(HealthPermissionService.mappingFor(HcPermissions.readVo2Max), isNull);
      expect(
        HealthPermissionService.mappingFor(HcPermissions.readMenstruationPeriod),
        isNull,
      );
      expect(HealthPermissionService.isMappable(HcPermissions.readElevation), isFalse);
    });

    test('resolve() de-duplicates and skips unmappable permissions', () {
      final resolved = HealthPermissionService.resolve({
        HcPermissions.readSteps,
        HcPermissions.readSteps, // duplicate
        HcPermissions.readBoneMass, // gap, skipped
        HcPermissions.readBloodPressure, // two types
      });
      expect(resolved.types, [
        HealthDataType.STEPS,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ]);
      expect(resolved.accesses.length, resolved.types.length);
      expect(resolved.accesses.every((a) => a == HealthDataAccess.READ), isTrue);
    });
  });
}
