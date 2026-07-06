import 'package:flutter/material.dart';

/// The canonical flat card used across the shell and charts, ported from the
/// Kotlin `OpenVitalsCard` (in `DetailCards.kt`): zero elevation, a
/// `surfaceContainer` background, and the Material medium (12dp) shape.
class OpenVitalsCard extends StatelessWidget {
  const OpenVitalsCard({
    super.key,
    required this.child,
    this.onTap,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Overrides the default `surfaceContainer` background.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color ?? scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}
