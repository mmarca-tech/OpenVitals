import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// Opens [url] in the system browser, the Flutter equivalent of the Kotlin
/// app's `LocalUriHandler.openUri`. Best-effort: on a malformed URL or a
/// platform that cannot launch it, a SnackBar reports the failure rather than
/// throwing.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  final uri = Uri.tryParse(url);
  var launched = false;
  if (uri != null) {
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
  }
  if (!launched) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.linkCouldNotOpen)),
    );
  }
}
