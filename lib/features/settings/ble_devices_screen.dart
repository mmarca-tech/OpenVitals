import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/providers.dart';
import '../../domain/model/ble_sensor_models.dart';
import '../../sensors/ble/ble_sensor_coordinator.dart';

/// A simple BLE sensor management screen: lists paired sensors (enable / remove)
/// and, while scanning, the discovered devices that can be paired. Replaces the
/// Phase-6 "coming soon" stub for the Sensors settings section.
///
/// The scan/connect stack is device-dependent; this screen drives the ported
/// [BleSensorCoordinator] over `flutter_blue_plus` and is not covered by tests.
class BleDevicesScreen extends ConsumerStatefulWidget {
  const BleDevicesScreen({super.key});

  @override
  ConsumerState<BleDevicesScreen> createState() => _BleDevicesScreenState();
}

class _BleDevicesScreenState extends ConsumerState<BleDevicesScreen> {
  bool _scanning = false;

  @override
  void dispose() {
    // Best-effort: stop scanning when leaving the screen.
    ref.read(bleSensorCoordinatorProvider).stopScan();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    final coordinator = ref.read(bleSensorCoordinatorProvider);
    if (_scanning) {
      await coordinator.stopScan();
      if (mounted) setState(() => _scanning = false);
    } else {
      setState(() => _scanning = true);
      await coordinator.startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = ref.watch(bleDevicesProvider).value ?? const [];
    final discovered = ref.watch(bleDiscoveredDevicesProvider).value ?? const [];
    final pairedAddresses = {
      for (final device in devices) device.address.toUpperCase(),
    };
    final unpaired = discovered
        .where((d) => !pairedAddresses.contains(d.address.toUpperCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Sensors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_scanning ? Icons.stop : Icons.bluetooth_searching),
        label: Text(_scanning ? 'Stop' : 'Scan'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _SectionHeader(title: 'Paired sensors', theme: theme),
          if (devices.isEmpty)
            const _EmptyHint(text: 'No sensors paired yet.')
          else
            for (final device in devices)
              _PairedDeviceTile(
                device: device,
                onToggle: (enabled) => ref
                    .read(bleDeviceRepositoryProvider)
                    .setDeviceEnabled(device.id, enabled),
                onRemove: () =>
                    ref.read(bleDeviceRepositoryProvider).removeDevice(device.id),
              ),
          _SectionHeader(
            title: _scanning ? 'Discovering…' : 'Discovered',
            theme: theme,
          ),
          if (unpaired.isEmpty)
            _EmptyHint(
              text: _scanning
                  ? 'Searching for nearby sensors…'
                  : 'Tap Scan to search for nearby sensors.',
            )
          else
            for (final device in unpaired)
              _DiscoveredDeviceTile(
                device: device,
                onPair: () => ref.read(bleDeviceRepositoryProvider).addDevice(
                      displayName: device.name ?? device.address,
                      address: device.address,
                      bluetoothName: device.name,
                      capabilities: device.suggestedCapabilities,
                    ),
              ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _PairedDeviceTile extends StatelessWidget {
  const _PairedDeviceTile({
    required this.device,
    required this.onToggle,
    required this.onRemove,
  });

  final BleSensorDevice device;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final capabilities = device.capabilities.map(_capabilityLabel).join(', ');
    final battery = device.batteryPercent;
    final subtitle = [
      if (capabilities.isNotEmpty) capabilities,
      if (battery != null) 'Battery $battery%',
    ].join(' · ');
    return ListTile(
      leading: const Icon(Icons.sensors),
      title: Text(device.displayName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(value: device.enabled, onChanged: onToggle),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _DiscoveredDeviceTile extends StatelessWidget {
  const _DiscoveredDeviceTile({required this.device, required this.onPair});

  final BleDiscoveredDevice device;
  final VoidCallback onPair;

  @override
  Widget build(BuildContext context) {
    final capabilities =
        device.suggestedCapabilities.map(_capabilityLabel).join(', ');
    final rssi = device.rssi;
    final subtitle = [
      device.address,
      if (rssi != null) '$rssi dBm',
      if (capabilities.isNotEmpty) capabilities,
    ].join(' · ');
    return ListTile(
      leading: const Icon(Icons.bluetooth),
      title: Text(device.name ?? device.address),
      subtitle: Text(subtitle),
      trailing: FilledButton.tonal(onPressed: onPair, child: const Text('Pair')),
    );
  }
}

String _capabilityLabel(BleSensorCapability capability) {
  switch (capability) {
    case BleSensorCapability.heartRate:
      return 'Heart rate';
    case BleSensorCapability.cyclingCadence:
      return 'Cadence';
    case BleSensorCapability.cyclingPower:
      return 'Power';
    case BleSensorCapability.cyclingSpeedDistance:
      return 'Speed';
    case BleSensorCapability.runningSpeedCadence:
      return 'Run speed/cadence';
  }
}
