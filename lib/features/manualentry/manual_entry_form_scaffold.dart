import 'package:flutter/material.dart';

import '../../core/presentation/screen_error.dart';

/// Renders a human-readable message for a [ScreenError], falling back to a
/// generic string. The Kotlin `ScreenError.resolve()` composable is not ported;
/// this mirrors its "unknown error" fallback.
String screenErrorText(ScreenError? error) {
  if (error is ScreenErrorMessage) return error.text;
  return 'Unknown error';
}

/// Signals a successful manual-entry write: shows a confirmation snackbar and
/// pops the entry route (the Kotlin `onEntrySaved` navigates back). Safe to call
/// after the write completes on the still-mounted screen context.
void onManualEntrySaved(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  Navigator.of(context).maybePop();
}
