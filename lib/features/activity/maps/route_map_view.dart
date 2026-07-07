import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/model/activity_models.dart';
import 'route_geometry.dart';

/// Renders a workout GPS route on a [FlutterMap], replacing the Kotlin
/// `OfflineRouteMapOrPreview` / MapLibre + Mapsforge composables.
///
/// The route is drawn as one [Polyline] per segment (breaks split the line),
/// with start / end / current-location markers, and the camera auto-fits the
/// route bounds.
///
/// Base map: an online OpenStreetMap raster tile layer is used as the default.
/// // TODO(offline-maps): plug the imported offline vector pack in here — a
/// PMTiles/MBTiles raster `TileProvider` (or a Mapsforge renderer) sourced from
/// `OfflineMapImportController`'s active pack would replace the network
/// [TileLayer]. Full offline vector parity with the Kotlin MapLibre/Mapsforge
/// path is deferred to on-device.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.routeBreakIndexes = const <int>[],
    this.currentPoint,
    this.height = 240,
    this.tileProvider,
    this.urlTemplate = _openStreetMapTiles,
  });

  final List<ExerciseRoutePoint> points;
  final List<int> routeBreakIndexes;
  final ExerciseRoutePoint? currentPoint;
  final double height;

  /// Overrides the tile source. Tests pass a network-free provider so no tiles
  /// are fetched; production leaves this null to use [urlTemplate].
  final TileProvider? tileProvider;

  /// Raster tile URL template used when [tileProvider] is null.
  final String urlTemplate;

  static const String _openStreetMapTiles =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const Color _routeColor = Color(0xFFD9462F);
  static const Color _startColor = Color(0xFF1F9D55);
  static const Color _endColor = Color(0xFF6B5DD3);
  static const Color _currentColor = Color(0xFF1D4ED8);

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  @override
  Widget build(BuildContext context) {
    final segments = routeSegments(widget.points, widget.routeBreakIndexes)
        .where((segment) => segment.length >= 2)
        .map((segment) => segment.map(_toLatLng).toList())
        .toList();

    final cameraPoints = <ExerciseRoutePoint>[
      ...widget.points,
      if (widget.currentPoint != null) widget.currentPoint!,
    ];
    final bounds = RouteBounds.fromPoints(cameraPoints);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          options: _mapOptions(bounds),
          children: [
            TileLayer(
              urlTemplate: widget.urlTemplate,
              userAgentPackageName: 'tech.mmarca.openvitals',
              tileProvider: widget.tileProvider,
            ),
            if (segments.isNotEmpty)
              PolylineLayer(
                polylines: [
                  for (final segment in segments)
                    Polyline(
                      points: segment,
                      color: RouteMapView._routeColor,
                      strokeWidth: 4,
                    ),
                ],
              ),
            MarkerLayer(markers: _markers()),
          ],
        ),
      ),
    );
  }

  MapOptions _mapOptions(RouteBounds? bounds) {
    if (bounds == null) {
      return const MapOptions(
        initialCenter: LatLng(0, 0),
        initialZoom: 1,
        interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
      );
    }
    if (bounds.isSinglePoint) {
      return MapOptions(
        initialCenter: LatLng(bounds.centerLatitude, bounds.centerLongitude),
        initialZoom: 15.5,
      );
    }
    return MapOptions(
      initialCameraFit: CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(bounds.minLatitude, bounds.minLongitude),
          LatLng(bounds.maxLatitude, bounds.maxLongitude),
        ),
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  List<Marker> _markers() {
    final validPoints = widget.points
        .where((point) => point.latitude.isFinite && point.longitude.isFinite)
        .toList();
    return [
      if (validPoints.isNotEmpty)
        _marker(validPoints.first, RouteMapView._startColor),
      if (validPoints.length > 1)
        _marker(validPoints.last, RouteMapView._endColor),
      if (widget.currentPoint != null &&
          widget.currentPoint!.latitude.isFinite &&
          widget.currentPoint!.longitude.isFinite)
        _marker(widget.currentPoint!, RouteMapView._currentColor, radius: 8),
    ];
  }

  Marker _marker(ExerciseRoutePoint point, Color color, {double radius = 6}) {
    final diameter = radius * 2;
    return Marker(
      point: _toLatLng(point),
      width: diameter + 4,
      height: diameter + 4,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  static LatLng _toLatLng(ExerciseRoutePoint point) =>
      LatLng(point.latitude, point.longitude);
}
