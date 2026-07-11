import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../navigation/app_routes.dart';
import '../../ui/components/ov_card.dart';
import 'dashboard_sensor_status.dart';

/// The dashboard's BLE sensor battery card (Kotlin `DashboardSensorStatusCard`):
/// a full-width tappable card showing the lowest battery across the paired
/// sensors plus an "N active • M connected" summary. Renders nothing when no
/// sensor is paired. Tapping opens the sensor settings screen.
class DashboardSensorStatusCard extends StatelessWidget {
  const DashboardSensorStatusCard({super.key, required this.status});

  final DashboardSensorStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.hasDevices) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final batteryPercent = status.lowestBatteryPercent;
    final accent = _accentColor(scheme, batteryPercent);
    final headline = batteryPercent != null
        ? l10n.dashboardSensorBatteryLowest(batteryPercent)
        : l10n.dashboardSensorBatteryUnknown;
    final supporting = status.enabledCount == 0
        ? l10n.dashboardSensorStatusAllDisabled
        : l10n.dashboardSensorStatusActiveConnected(
            status.enabledCount,
            status.connectedCount,
          );

    return OpenVitalsCard(
      onTap: () => context.push(AppRoutes.settingsSensors),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.battery_charging_full_outlined,
                      size: 21,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.dashboardSensorStatusTitle,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headline,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(
                supporting,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kotlin `sensorBatteryAccentColor`: error below 20%, tertiary below 40%,
  /// primary otherwise (and while the battery is still unknown).
  Color _accentColor(ColorScheme scheme, int? percent) {
    if (percent == null) return scheme.primary;
    if (percent <= 20) return scheme.error;
    if (percent <= 40) return scheme.tertiary;
    return scheme.primary;
  }
}
