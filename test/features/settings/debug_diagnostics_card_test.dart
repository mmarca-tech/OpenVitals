import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:openvitals/features/settings/cards/debug_diagnostics_card.dart';
import 'package:openvitals/l10n/app_localizations.dart';

void main() {
  Widget harness(DebugDiagnosticsCard card) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: card)),
      );

  PackageInfo fakeInfo() => PackageInfo(
        appName: 'OpenVitals',
        packageName: 'tech.mmarca.openvitals',
        version: '1.2.3',
        buildNumber: '42',
      );

  testWidgets('renders the title, body and save action', (tester) async {
    await tester.pumpWidget(harness(const DebugDiagnosticsCard()));
    await tester.pumpAndSettle();

    expect(find.text('Sanitized diagnostics logs'), findsOneWidget);
    expect(find.text('Save logs'), findsOneWidget);
  });

  testWidgets('save flow sanitizes the logcat and reports success',
      (tester) async {
    String? savedContent;
    String? savedName;
    await tester.pumpWidget(harness(DebugDiagnosticsCard(
      readLogcat: () async => const [
        'I/OpenVitalsX: kept line',
        'I/RandomTag: dropped tag',
      ],
      loadPackageInfo: () async => fakeInfo(),
      saveLogsFile: (content, name) async {
        savedContent = content;
        savedName = name;
        return true;
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save logs'));
    await tester.pumpAndSettle();

    expect(savedName, 'openvitals-diagnostics-logs.txt');
    expect(savedContent, contains('package=tech.mmarca.openvitals'));
    expect(savedContent, contains('version=1.2.3 (42)'));
    expect(savedContent, contains('I/OpenVitalsX: kept line'));
    expect(savedContent, isNot(contains('I/RandomTag: dropped tag')));
    expect(find.text('Debug logs saved'), findsOneWidget);
  });

  testWidgets('degrades gracefully when the native channel is unavailable',
      (tester) async {
    var saveCalled = false;
    await tester.pumpWidget(harness(DebugDiagnosticsCard(
      readLogcat: () async => null,
      loadPackageInfo: () async => fakeInfo(),
      saveLogsFile: (content, name) async {
        saveCalled = true;
        return true;
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save logs'));
    await tester.pumpAndSettle();

    expect(saveCalled, isFalse);
    expect(find.text('Could not save diagnostics logs'), findsOneWidget);
  });
  // The card is only reachable in debug builds; keep the test aligned with the
  // kDebugMode gate so it never runs against a release profile.
}
