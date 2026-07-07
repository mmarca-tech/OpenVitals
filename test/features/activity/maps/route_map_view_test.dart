import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvitals/domain/model/activity_models.dart';
import 'package:openvitals/features/activity/maps/route_map_view.dart';

/// A tile provider that never touches the network: it returns a 1x1
/// transparent PNG so widget tests can pump [RouteMapView] without fetching
/// map tiles.
class _TransparentTileProvider extends TileProvider {
  static final Uint8List _pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

ExerciseRoutePoint point(double lat, double lng, int seconds) =>
    ExerciseRoutePoint(
      time: DateTime.utc(2026, 6, 1).add(Duration(seconds: seconds)),
      latitude: lat,
      longitude: lng,
      altitudeMeters: null,
      horizontalAccuracyMeters: null,
      verticalAccuracyMeters: null,
    );

void main() {
  testWidgets('renders a polyline route without fetching network tiles',
      (tester) async {
    final points = [
      point(52.5200, 13.4050, 0),
      point(52.5205, 13.4062, 10),
      point(52.5210, 13.4075, 20),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: RouteMapView(
              points: points,
              currentPoint: points.last,
              tileProvider: _TransparentTileProvider(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles an empty route gracefully', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: RouteMapView(
              points: const [],
              tileProvider: _TransparentTileProvider(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
