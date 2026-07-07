/// Streaming Apple Health `export.xml` / `export.zip` parser, ported from the
/// Kotlin `AppleHealthImportParser.kt`.
///
/// Uses `package:xml`'s event API (`parseEvents`) so the document is consumed as
/// a stream of start/end/text events without materializing a DOM, and
/// `package:archive` to read `export.xml` (and workout-route GPX files) out of a
/// zipped export. Character repair and DTD stripping happen in
/// `apple_health_import_xml_support.dart` before any event is emitted.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'apple_health_import_models.dart';
import 'apple_health_import_route_parser.dart';
import 'apple_health_import_types.dart';
import 'apple_health_import_xml_support.dart';

class AppleHealthParseOptions {
  const AppleHealthParseOptions({
    this.parseRouteFiles = true,
    this.parseRecordDetails = true,
  });

  final bool parseRouteFiles;
  final bool parseRecordDetails;
}

/// Streaming consumer callbacks (Kotlin `AppleHealthXmlEventConsumer`).
abstract interface class AppleHealthXmlEventConsumer {
  void onParsedType(String type);
  void onRecord(AppleRecord record);
  void onWorkout(AppleWorkout workout);
  void onCorrelation(AppleCorrelation correlation);
  void onActivitySummary();
}

class AppleHealthImportParser {
  const AppleHealthImportParser._();

  static AppleParsedExport parse(
    List<int> bytes, {
    AppleHealthXmlEventConsumer? consumer,
    AppleHealthParseOptions options = const AppleHealthParseOptions(),
    Map<String, AppleWorkoutRouteFile> routeFiles = const {},
  }) {
    if (_hasZipHeader(bytes)) {
      return _parseZipExport(bytes, consumer, routeFiles, options);
    }
    final xml = utf8.decode(bytes, allowMalformed: true);
    return _parseXmlExport(xml, consumer, routeFiles, options.parseRecordDetails);
  }

  static AppleParsedExport _parseZipExport(
    List<int> bytes,
    AppleHealthXmlEventConsumer? consumer,
    Map<String, AppleWorkoutRouteFile> routeFiles,
    AppleHealthParseOptions options,
  ) {
    final archive = ZipDecoder().decodeBytes(bytes);
    List<int>? exportXmlBytes;
    final resolvedRouteFiles =
        Map<String, AppleWorkoutRouteFile>.of(routeFiles);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = file.name;
      if (_isAppleHealthExportXml(name)) {
        exportXmlBytes = file.content as List<int>;
      } else if (options.parseRouteFiles && _isAppleWorkoutRouteFile(name)) {
        final gpx = utf8.decode(file.content as List<int>, allowMalformed: true);
        final routeFile = AppleHealthImportRouteParser.parse(name, gpx);
        if (routeFile != null) resolvedRouteFiles[routeFile.path] = routeFile;
      }
    }
    if (exportXmlBytes == null) {
      throw ArgumentError('Apple Health export.zip must contain export.xml.');
    }
    final xml = utf8.decode(exportXmlBytes, allowMalformed: true);
    return _parseXmlExport(
      xml,
      consumer,
      resolvedRouteFiles,
      options.parseRecordDetails,
    );
  }

  static AppleParsedExport _parseXmlExport(
    String rawXml,
    AppleHealthXmlEventConsumer? consumer,
    Map<String, AppleWorkoutRouteFile> routeFiles,
    bool parseRecordDetails,
  ) {
    final sanitized = sanitizeAppleHealthXml(rawXml);
    final handler = _AppleHealthXmlHandler(consumer, routeFiles, parseRecordDetails);
    try {
      for (final event in parseEvents(
        sanitized.text,
        validateNesting: true,
        withBuffer: true,
      )) {
        if (event is XmlStartElementEvent) {
          handler.startElement(event.name, event.attributes);
          if (event.isSelfClosing) handler.endElement(event.name);
        } else if (event is XmlEndElementEvent) {
          handler.endElement(event.name);
        }
      }
    } on XmlException catch (error) {
      final position = error is XmlParserException
          ? (error.position ?? sanitized.text.length)
          : sanitized.text.length;
      final start = position - 200 < 0 ? 0 : position - 200;
      final end = position > sanitized.text.length ? sanitized.text.length : position;
      throw AppleHealthXmlParseException(buildAppleHealthXmlParseMessage(
        location: 'position $position',
        causeMessage: error.message,
        recentContext: sanitized.text.substring(start, end),
        strippedControlChars: sanitized.strippedControlChars,
        escapedAmpersands: sanitized.escapedAmpersands,
      ));
    }
    return handler.result(
      sanitizedControlChars: sanitized.strippedControlChars,
      sanitizedAmpersands: sanitized.escapedAmpersands,
    );
  }
}

// ── Streaming date parsing ────────────────────────────────────────────────

final RegExp _appleDateTimeRegex = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?\s*'
  r'([+-]\d{2}:?\d{2}|[Zz])?$',
);

/// Parses an Apple export timestamp, preserving its wall-clock offset. Handles
/// `yyyy-MM-dd HH:mm:ss ±ZZZZ`, fractional seconds, local (no-offset), and ISO.
AppleDateTime? parseAppleDateTime(String value) {
  final match = _appleDateTimeRegex.firstMatch(value.trim());
  if (match != null) {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final fraction = match.group(7);
    final millis =
        fraction == null ? 0 : int.parse('${fraction}000'.substring(0, 3));
    final offsetText = match.group(8);
    if (offsetText != null && offsetText.isNotEmpty) {
      final Duration offset;
      if (offsetText == 'Z' || offsetText == 'z') {
        offset = Duration.zero;
      } else {
        final sign = offsetText[0] == '-' ? -1 : 1;
        final digits = offsetText.substring(1).replaceAll(':', '');
        offset = Duration(
              hours: int.parse(digits.substring(0, 2)),
              minutes: int.parse(digits.substring(2, 4)),
            ) *
            sign;
      }
      final wall = DateTime.utc(year, month, day, hour, minute, second, millis);
      return AppleDateTime(wall.subtract(offset), offset);
    }
    final wall = DateTime(year, month, day, hour, minute, second, millis);
    return AppleDateTime(wall.toUtc(), wall.timeZoneOffset);
  }
  final parsed = DateTime.tryParse(value.trim());
  if (parsed != null) return AppleDateTime(parsed.toUtc(), Duration.zero);
  return null;
}

// ── Event handler ─────────────────────────────────────────────────────────

abstract class _MutableElement {
  final Map<String, String> metadata = {};
}

class _MutableWorkoutRoute extends _MutableElement {
  final List<String> paths = [];
}

class _MutableRecord extends _MutableElement {
  _MutableRecord(Map<String, String> attrs, this.parentCorrelation, this.parseDetails)
      : type = attrs['type'] ?? 'Record',
        sourceName = attrs['sourceName'],
        sourceVersion = attrs['sourceVersion'],
        device = attrs['device'],
        unit = attrs['unit'],
        creationDate = _appleDate(attrs['creationDate'], parseDetails),
        startDate = _appleDate(attrs['startDate'], parseDetails),
        endDate = _appleDate(attrs['endDate'], parseDetails),
        rawValue = attrs['value'];

  final String type;
  final String? sourceName;
  final String? sourceVersion;
  final String? device;
  final String? unit;
  final AppleDateTime? creationDate;
  final AppleDateTime? startDate;
  final AppleDateTime? endDate;
  final String? rawValue;
  final _MutableCorrelation? parentCorrelation;
  final bool parseDetails;

  AppleRecord toRecord() => AppleRecord(
        type: type,
        sourceName: sourceName,
        sourceVersion: sourceVersion,
        device: device,
        unit: unit,
        creationDate: creationDate,
        startDate: startDate,
        endDate: endDate,
        rawValue: rawValue,
        numericValue: parseDetails ? double.tryParse(rawValue ?? '') : null,
        metadata: Map.of(metadata),
        correlationType: parentCorrelation?.type,
      );
}

class _MutableWorkout extends _MutableElement {
  _MutableWorkout(Map<String, String> attrs, bool parseDetails)
      : workoutActivityType = attrs['workoutActivityType'] ?? 'Workout',
        sourceName = attrs['sourceName'],
        sourceVersion = attrs['sourceVersion'],
        device = attrs['device'],
        creationDate = _appleDate(attrs['creationDate'], parseDetails),
        startDate = _appleDate(attrs['startDate'], parseDetails),
        endDate = _appleDate(attrs['endDate'], parseDetails),
        duration = double.tryParse(attrs['duration'] ?? ''),
        durationUnit = attrs['durationUnit'],
        totalDistance = double.tryParse(attrs['totalDistance'] ?? ''),
        totalDistanceUnit = attrs['totalDistanceUnit'],
        totalEnergyBurned = double.tryParse(attrs['totalEnergyBurned'] ?? ''),
        totalEnergyBurnedUnit = attrs['totalEnergyBurnedUnit'] {
    _hasTotalDistanceAttribute = totalDistance != null;
    _hasTotalEnergyBurnedAttribute = totalEnergyBurned != null;
  }

  final String workoutActivityType;
  final String? sourceName;
  final String? sourceVersion;
  final String? device;
  final AppleDateTime? creationDate;
  final AppleDateTime? startDate;
  final AppleDateTime? endDate;
  final double? duration;
  final String? durationUnit;
  double? totalDistance;
  String? totalDistanceUnit;
  double? totalEnergyBurned;
  String? totalEnergyBurnedUnit;
  late final bool _hasTotalDistanceAttribute;
  late final bool _hasTotalEnergyBurnedAttribute;
  final List<AppleWorkoutEvent> events = [];
  final List<AppleWorkoutRouteFile> routes = [];
  int routeReferences = 0;

  void addStatistic(Map<String, String> attrs) {
    final type = attrs['type'];
    if (type == null) return;
    final sum = double.tryParse(attrs['sum'] ?? '');
    if (sum == null) return;
    final unit = attrs['unit'];
    if (appleDistanceTypes.contains(type)) {
      if (!_hasTotalDistanceAttribute) {
        totalDistance = _addCompatible(totalDistance, sum, totalDistanceUnit, unit);
      }
      totalDistanceUnit ??= unit;
    } else if (type == appleActiveEnergyBurned) {
      if (!_hasTotalEnergyBurnedAttribute) {
        totalEnergyBurned =
            _addCompatible(totalEnergyBurned, sum, totalEnergyBurnedUnit, unit);
      }
      totalEnergyBurnedUnit ??= unit;
    }
  }

  void addRoute(AppleWorkoutRouteFile route) => routes.add(route);

  AppleWorkout toWorkout() {
    final deduped = <String, AppleWorkoutRouteFile>{};
    for (final route in routes) {
      deduped.putIfAbsent(route.path, () => route);
    }
    return AppleWorkout(
      workoutActivityType: workoutActivityType,
      sourceName: sourceName,
      sourceVersion: sourceVersion,
      device: device,
      creationDate: creationDate,
      startDate: startDate,
      endDate: endDate,
      duration: duration,
      durationUnit: durationUnit,
      totalDistance: totalDistance,
      totalDistanceUnit: totalDistanceUnit,
      totalEnergyBurned: totalEnergyBurned,
      totalEnergyBurnedUnit: totalEnergyBurnedUnit,
      metadata: Map.of(metadata),
      events: List.of(events),
      routes: deduped.values.toList(),
      routeReferences: routeReferences,
    );
  }
}

double _addCompatible(
  double? current,
  double value,
  String? currentUnit,
  String? valueUnit,
) {
  if (current == null || currentUnit == null || currentUnit == valueUnit) {
    return (current ?? 0.0) + value;
  }
  return current;
}

class _MutableCorrelation extends _MutableElement {
  _MutableCorrelation(Map<String, String> attrs, bool parseDetails)
      : type = attrs['type'] ?? 'Correlation',
        sourceName = attrs['sourceName'],
        sourceVersion = attrs['sourceVersion'],
        device = attrs['device'],
        creationDate = _appleDate(attrs['creationDate'], parseDetails),
        startDate = _appleDate(attrs['startDate'], parseDetails),
        endDate = _appleDate(attrs['endDate'], parseDetails);

  final String type;
  final String? sourceName;
  final String? sourceVersion;
  final String? device;
  final AppleDateTime? creationDate;
  final AppleDateTime? startDate;
  final AppleDateTime? endDate;
  final List<AppleRecord> records = [];

  AppleCorrelation toCorrelation() => AppleCorrelation(
        type: type,
        sourceName: sourceName,
        sourceVersion: sourceVersion,
        device: device,
        creationDate: creationDate,
        startDate: startDate,
        endDate: endDate,
        metadata: Map.of(metadata),
        records: List.of(records),
      );
}

AppleDateTime? _appleDate(String? value, bool parseDetails) {
  if (!parseDetails || value == null) return null;
  return parseAppleDateTime(value);
}

class _AppleHealthXmlHandler {
  _AppleHealthXmlHandler(this._consumer, this._routeFiles, this._parseRecordDetails);

  final AppleHealthXmlEventConsumer? _consumer;
  final Map<String, AppleWorkoutRouteFile> _routeFiles;
  final bool _parseRecordDetails;

  final List<_MutableElement> _stack = [];
  final List<AppleRecord> _records = [];
  final List<AppleWorkout> _workouts = [];
  final List<AppleCorrelation> _correlations = [];
  final Map<String, int> _typeCounts = {};
  int _parsedRecords = 0;
  int _parsedWorkouts = 0;
  int _parsedCorrelations = 0;
  int _parsedActivitySummaries = 0;

  _MutableElement? get _top => _stack.isEmpty ? null : _stack.last;

  void startElement(String name, List<XmlEventAttribute> rawAttributes) {
    switch (name) {
      case 'Record':
        _parsedRecords++;
        final attrs = _attributes(rawAttributes);
        final type = attrs['type'] ?? 'Record';
        _countType(type);
        _consumer?.onParsedType(type);
        final parent = _top is _MutableCorrelation ? _top as _MutableCorrelation : null;
        _stack.add(_MutableRecord(attrs, parent, _parseRecordDetails));
      case 'Workout':
        _parsedWorkouts++;
        final attrs = _attributes(rawAttributes);
        final type = attrs['workoutActivityType'] ?? 'Workout';
        _countType(type);
        _consumer?.onParsedType(type);
        _stack.add(_MutableWorkout(attrs, _parseRecordDetails));
      case 'Correlation':
        _parsedCorrelations++;
        final attrs = _attributes(rawAttributes);
        final type = attrs['type'] ?? 'Correlation';
        _countType(type);
        _consumer?.onParsedType(type);
        _stack.add(_MutableCorrelation(attrs, _parseRecordDetails));
      case 'MetadataEntry':
        if (!_parseRecordDetails) return;
        final attrs = _attributes(rawAttributes);
        final key = attrs['key'];
        final value = attrs['value'];
        if (key != null && value != null) {
          _top?.metadata[key] = value;
        }
      case 'WorkoutEvent':
        final workout = _top;
        if (workout is! _MutableWorkout) return;
        final attrs = _attributes(rawAttributes);
        workout.events.add(AppleWorkoutEvent(
          type: attrs['type'],
          date: _appleDate(attrs['date'], _parseRecordDetails),
          duration: double.tryParse(attrs['duration'] ?? ''),
          durationUnit: attrs['durationUnit'],
        ));
      case 'WorkoutStatistics':
        final workout = _top;
        if (workout is! _MutableWorkout) return;
        workout.addStatistic(_attributes(rawAttributes));
      case 'WorkoutRoute':
        if (_top is _MutableWorkout) {
          _stack.add(_MutableWorkoutRoute());
        }
      case 'FileReference':
        final route = _top;
        if (route is! _MutableWorkoutRoute) return;
        final path = _attributes(rawAttributes)['path'];
        if (path != null) route.paths.add(path);
      case 'ActivitySummary':
        _parsedActivitySummaries++;
        _countType('ActivitySummary');
        _consumer?.onParsedType('ActivitySummary');
        _consumer?.onActivitySummary();
    }
  }

  void endElement(String name) {
    switch (name) {
      case 'Record':
        final element = _removeTop<_MutableRecord>();
        if (element == null) return;
        final record = element.toRecord();
        final parent = _top is _MutableCorrelation ? _top as _MutableCorrelation : null;
        if (parent != null) {
          parent.records.add(record.copyWith(correlationType: parent.type));
        } else if (_consumer != null) {
          _consumer.onRecord(record);
        } else {
          _records.add(record);
        }
      case 'Workout':
        final element = _removeTop<_MutableWorkout>();
        if (element == null) return;
        final workout = element.toWorkout();
        if (_consumer != null) {
          _consumer.onWorkout(workout);
        } else {
          _workouts.add(workout);
        }
      case 'Correlation':
        final element = _removeTop<_MutableCorrelation>();
        if (element == null) return;
        final correlation = element.toCorrelation();
        if (_consumer != null) {
          _consumer.onCorrelation(correlation);
        } else {
          _correlations.add(correlation);
        }
      case 'WorkoutRoute':
        final route = _removeTop<_MutableWorkoutRoute>();
        if (route == null) return;
        final workout = _top;
        if (workout is! _MutableWorkout) return;
        final referencedPaths = <String>{};
        for (final path in route.paths) {
          referencedPaths.add(normalizedAppleWorkoutRoutePath(path));
        }
        workout.routeReferences += referencedPaths.length;
        for (final path in referencedPaths) {
          final routeFile = _routeFiles[path];
          if (routeFile != null) workout.addRoute(routeFile);
        }
    }
  }

  T? _removeTop<T extends _MutableElement>() {
    if (_stack.isEmpty || _stack.last is! T) return null;
    return _stack.removeLast() as T;
  }

  void _countType(String type) => _typeCounts[type] = (_typeCounts[type] ?? 0) + 1;

  AppleParsedExport result({
    required int sanitizedControlChars,
    required int sanitizedAmpersands,
  }) =>
      AppleParsedExport(
        records: _records,
        workouts: _workouts,
        correlations: _correlations,
        parsedRecords: _parsedRecords,
        parsedWorkouts: _parsedWorkouts,
        parsedCorrelations: _parsedCorrelations,
        parsedActivitySummaries: _parsedActivitySummaries,
        parsedTypeCounts: _typeCounts,
        sanitizedControlChars: sanitizedControlChars,
        sanitizedAmpersands: sanitizedAmpersands,
      );
}

Map<String, String> _attributes(List<XmlEventAttribute> attributes) {
  final result = <String, String>{};
  for (final attribute in attributes) {
    final value = attribute.value;
    if (value.trim().isNotEmpty) result[attribute.name] = value;
  }
  return result;
}

bool _hasZipHeader(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;

bool _isAppleHealthExportXml(String name) {
  final normalized = name.replaceAll('\\', '/');
  final base = normalized.substring(normalized.lastIndexOf('/') + 1).toLowerCase();
  return base == 'export.xml';
}

bool _isAppleWorkoutRouteFile(String name) {
  final path = normalizedAppleWorkoutRoutePath(name);
  return path.startsWith('workout-routes/') && path.endsWith('.gpx');
}
