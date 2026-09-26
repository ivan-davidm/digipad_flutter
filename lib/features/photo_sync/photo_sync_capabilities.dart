import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper over the native `ar.com.digipad.photosync/capabilities`
/// MethodChannel. Every call degrades gracefully (returns a safe default and
/// never throws) so the photo-sync flow keeps working even if a handler is
/// missing on a given build.
class PhotoSyncCapabilities {
  static const MethodChannel _ch =
      MethodChannel('ar.com.digipad.photosync/capabilities');

  static Future<bool> _bool(String method, {bool fallback = true}) async {
    try {
      final v = await _ch.invokeMethod<bool>(method);
      return v ?? fallback;
    } catch (e) {
      debugPrint('[PhotoSyncCapabilities] $method failed: $e');
      return fallback;
    }
  }

  static Future<void> _invoke(String method) async {
    try {
      await _ch.invokeMethod(method);
    } catch (e) {
      debugPrint('[PhotoSyncCapabilities] $method failed: $e');
    }
  }

  /// System location toggle (not the app permission). `true` when unknown so
  /// we never block on a false negative.
  static Future<bool> isLocationEnabled() => _bool('isLocationEnabled');

  static Future<bool> isWifiEnabled() => _bool('isWifiEnabled');

  static Future<bool> isBluetoothEnabled() => _bool('isBluetoothEnabled');

  static Future<void> openLocationSettings() => _invoke('openLocationSettings');

  static Future<void> openWifiSettings() => _invoke('openWifiSettings');

  static Future<void> openBluetoothSettings() =>
      _invoke('openBluetoothSettings');

  /// Hold a Wi-Fi multicast lock so the device receives the LAN discovery
  /// UDP broadcast beacon while it is in power-save. Always release it.
  static Future<void> acquireMulticastLock() => _invoke('acquireMulticastLock');

  static Future<void> releaseMulticastLock() => _invoke('releaseMulticastLock');

  /// `{isAndroidTV, hasBluetooth, hasBle, hasWifiDirect}` — empty map on error.
  static Future<Map<String, dynamic>> capabilities() async {
    try {
      final v = await _ch.invokeMethod<Map<dynamic, dynamic>>('getCapabilities');
      return v == null
          ? const {}
          : v.map((k, val) => MapEntry(k.toString(), val));
    } catch (e) {
      debugPrint('[PhotoSyncCapabilities] getCapabilities failed: $e');
      return const {};
    }
  }
}

/// Snapshot of the device radios/toggles relevant to photo sync.
class PhotoSyncReadiness {
  final bool locationOn;
  final bool wifiOn;
  final bool bluetoothOn;

  const PhotoSyncReadiness({
    required this.locationOn,
    required this.wifiOn,
    required this.bluetoothOn,
  });

  static Future<PhotoSyncReadiness> read() async {
    final results = await Future.wait([
      PhotoSyncCapabilities.isLocationEnabled(),
      PhotoSyncCapabilities.isWifiEnabled(),
      PhotoSyncCapabilities.isBluetoothEnabled(),
    ]);
    return PhotoSyncReadiness(
      locationOn: results[0],
      wifiOn: results[1],
      bluetoothOn: results[2],
    );
  }

  /// LAN transport only needs Wi-Fi.
  bool get lanUsable => wifiOn;

  /// Nearby Connections needs Bluetooth + (location services, because the
  /// current build keeps BLE scanning location-coupled on some OEMs).
  bool get nearbyUsable => bluetoothOn;
}
