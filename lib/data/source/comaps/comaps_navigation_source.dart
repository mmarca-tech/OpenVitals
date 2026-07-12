import 'package:flutter/services.dart';

/// The platform side of the CoMaps integration: a ContentResolver query, a
/// PackageManager lookup, a runtime permission grant and an intent launch —
/// none of which Dart can do.
///
/// It classifies nothing. It reports the status the platform found and hands the
/// raw provider row up unchanged, so that the decisions ("is this navigating?",
/// "is this the same guidance as a second ago?") stay in Dart, where they can be
/// tested without a device.
class CoMapsNavigationSource {
  const CoMapsNavigationSource({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'tech.mmarca.openvitals/comaps_navigation';

  final MethodChannel _channel;

  /// `{status: ..., row: {...}?, message: ...?}` — see the native
  /// `queryCoMapsLive`. A platform failure is reported as an `error` status
  /// rather than thrown: a recording must not stop because a map app did.
  Future<Map<Object?, Object?>> queryLive() async {
    try {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>('queryLive');
      return result ?? const {'status': 'error'};
    } on PlatformException catch (error) {
      return {'status': 'error', 'message': error.message};
    } on MissingPluginException {
      // Not Android. There is no CoMaps here.
      return const {'status': 'appUnavailable'};
    }
  }

  Future<bool> hasPermission() async =>
      await _invokeBool('hasPermission') ?? false;

  Future<bool> requestPermission() async =>
      await _invokeBool('requestPermission') ?? false;

  Future<bool> canLaunch() async => await _invokeBool('canLaunch') ?? false;

  /// Opens CoMaps, centred on [latitude]/[longitude] when they are known.
  Future<bool> launchForPlanning({double? latitude, double? longitude}) async =>
      await _invokeBool('launchForPlanning', {
        'latitude': latitude,
        'longitude': longitude,
      }) ??
      false;

  Future<bool?> _invokeBool(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<bool>(method, args);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
