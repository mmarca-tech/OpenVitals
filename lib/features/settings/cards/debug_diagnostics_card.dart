import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/diagnostics/debug_log_sanitizer.dart';
import '../../../core/diagnostics/logcat_reader.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/components/ov_card.dart';

/// Settings "Debug diagnostics" card — a faithful port of the Kotlin
/// `DebugDiagnosticsCard` (`SettingsCards.kt`): a bug-report icon, the sanitized
/// diagnostics-logs title/body, and a single "Save logs" action.
///
/// The action reads the current process logcat over the native
/// [LogcatReader] channel, privacy-sanitizes it in pure Dart via
/// [DebugLogSanitizer], and writes the result to a user-chosen file (default
/// name `openvitals-diagnostics-logs.txt`). The section is only reachable in
/// debug builds (gated on `kDebugMode` in the hub + router), mirroring Kotlin's
/// `BuildConfig.OPENVITALS_DIAGNOSTICS`.
class DebugDiagnosticsCard extends StatelessWidget {
  const DebugDiagnosticsCard({
    super.key,
    this.readLogcat,
    this.loadPackageInfo,
    this.saveLogsFile,
  });

  /// Test seam for the native logcat read; defaults to the platform channel.
  /// A `null` return means the channel is unavailable (non-Android / release).
  final Future<List<String>?> Function()? readLogcat;

  /// Test seam for package metadata; defaults to `PackageInfo.fromPlatform`.
  final Future<PackageInfo> Function()? loadPackageInfo;

  /// Test seam for the save flow; defaults to [_defaultSaveLogs]. Returns
  /// `true` on success.
  final Future<bool> Function(String content, String suggestedName)?
      saveLogsFile;

  static const String _suggestedName = 'openvitals-diagnostics-logs.txt';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: OpenVitalsCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.bug_report_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsDebugLogsTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l10n.settingsDebugLogsBody,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _saveLogs(context, l10n),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.settingsDebugLogsSave),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveLogs(BuildContext context, AppLocalizations l10n) async {
    final reader = readLogcat ?? const LogcatReader().readCurrentProcessLogcat;
    final rawLines = await reader();
    if (rawLines == null) {
      // Channel unavailable (non-Android host or release build) — degrade
      // gracefully rather than crashing.
      if (context.mounted) _showResult(context, l10n, ok: false);
      return;
    }
    final info =
        await (loadPackageInfo?.call() ?? PackageInfo.fromPlatform());
    final text = DebugLogSanitizer.buildExportText(
      packageName: info.packageName,
      versionName: info.version,
      versionCode: int.tryParse(info.buildNumber) ?? 0,
      rawLines: rawLines,
    );
    final saver = saveLogsFile ?? _defaultSaveLogs;
    final ok = await saver(text, _suggestedName);
    if (context.mounted) _showResult(context, l10n, ok: ok);
  }

  void _showResult(
    BuildContext context,
    AppLocalizations l10n, {
    required bool ok,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.settingsDebugLogsSaved : l10n.settingsDebugLogsSaveFailed,
        ),
      ),
    );
  }

  /// Writes the export to a user-chosen location where `getSaveLocation` is
  /// supported (desktop), falling back to the app documents directory on
  /// platforms whose `file_selector` implementation has no save picker
  /// (Android — the analogue of Kotlin's SAF `CreateDocument`). Mirrors the
  /// Apple-Health report save flow.
  static Future<bool> _defaultSaveLogs(
    String content,
    String suggestedName,
  ) async {
    try {
      final location = await getSaveLocation(suggestedName: suggestedName);
      if (location == null) return false;
      await File(location.path).writeAsString(content);
      return true;
    } catch (_) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        await File('${dir.path}/$suggestedName').writeAsString(content);
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
