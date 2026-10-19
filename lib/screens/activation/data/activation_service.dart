import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ActivationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static const String _collectionName = 'device_activations';
  static const String _offlineInteractionsKey = 'offline_interactions_count';
  static const int _maxOfflineInteractions = 1000;
  static const String _isApprovedKey = 'is_device_approved_locally';
  static const String _savedEmailKey = 'saved_activation_email';
  static const String _deviceIdKey = 'activation_device_id';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sharedPrefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  String? _cachedDeviceId;

  Future<String?> getSavedEmail() async {
    final prefs = await _sharedPrefs;
    return prefs.getString(_savedEmailKey);
  }

  Future<void> saveEmail(String email) async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_savedEmailKey, email);
  }

  Future<void> clearSavedEmail() async {
    final prefs = await _sharedPrefs;
    await prefs.remove(_savedEmailKey);
  }

  Future<bool> checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  Future<int> getOfflineInteractionsCount() async {
    final prefs = await _sharedPrefs;
    return prefs.getInt(_offlineInteractionsKey) ?? 0;
  }

  Future<void> incrementOfflineInteractions() async {
    final prefs = await _sharedPrefs;
    int current = prefs.getInt(_offlineInteractionsKey) ?? 0;
    await prefs.setInt(_offlineInteractionsKey, current + 1);
  }

  Future<void> resetOfflineInteractions() async {
    final prefs = await _sharedPrefs;
    await prefs.setInt(_offlineInteractionsKey, 0);
  }

  bool isOfflineLimitReached(int count) {
    return count >= _maxOfflineInteractions;
  }

  Future<bool> isLocallyApproved() async {
    final prefs = await _sharedPrefs;
    return prefs.getBool(_isApprovedKey) ?? false;
  }

  Future<void> setLocallyApproved(bool approved) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(_isApprovedKey, approved);
  }

  // Note: we deliberately do NOT derive this from device_info_plus.
  // On Android, `androidInfo.id` maps to Build.ID, which is the OS build
  // identifier (e.g. "TQ3A.230901.001") — identical across every device
  // running the same firmware/OTA image, not a per-device identifier. Two
  // unrelated physical devices (different stores, different owners) can
  // easily share it, which previously caused one activation to collide
  // with and overwrite/delete another. A locally generated, persisted
  // UUID is guaranteed unique per install regardless of platform quirks.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await _sharedPrefs;
    String? storedId = prefs.getString(_deviceIdKey);
    if (storedId == null) {
      storedId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, storedId);
    }

    _cachedDeviceId = storedId;
    return storedId;
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    late final PackageInfo packageInfo;
    AndroidDeviceInfo? androidInfo;
    IosDeviceInfo? iosInfo;

    final futures = <Future>[
      PackageInfo.fromPlatform().then((value) => packageInfo = value),
    ];

    if (Platform.isAndroid) {
      futures.add(_deviceInfo.androidInfo.then((value) => androidInfo = value));
    } else if (Platform.isIOS) {
      futures.add(_deviceInfo.iosInfo.then((value) => iosInfo = value));
    }

    await Future.wait(futures);

    Map<String, dynamic> deviceData = {
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'platform': Platform.operatingSystem,
    };

    if (Platform.isAndroid && androidInfo != null) {
      deviceData.addAll({
        'brand': androidInfo!.brand,
        'model': androidInfo!.model,
        'device': androidInfo!.device,
        'version': androidInfo!.version.release,
        'sdkInt': androidInfo!.version.sdkInt,
        'manufacturer': androidInfo!.manufacturer,
      });
    } else if (Platform.isIOS && iosInfo != null) {
      deviceData.addAll({
        'name': iosInfo!.name,
        'systemName': iosInfo!.systemName,
        'systemVersion': iosInfo!.systemVersion,
        'model': iosInfo!.model,
        'localizedModel': iosInfo!.localizedModel,
        'isPhysicalDevice': iosInfo!.isPhysicalDevice,
      });
    }
    return deviceData;
  }

  Future<String?> _getIpAddress() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (_) {}
    return null;
  }

  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> getActivationStream(
    String email,
  ) async* {
    final deviceId = await getDeviceId();
    final docId = '${email}_$deviceId';
    yield* _firestore.collection(_collectionName).doc(docId).snapshots();
  }

  Future<bool> checkApprovalStatus() async {
    try {
      final savedEmail = await getSavedEmail();
      if (savedEmail == null) return false;

      final deviceId = await getDeviceId();
      final docId = '${savedEmail}_$deviceId';
      final doc = await _firestore.collection(_collectionName).doc(docId).get();

      if (doc.exists) {
        final data = doc.data();
        await updateLastAccess(savedEmail);
        return data?['isApproved'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> updateLastAccess(String email) async {
    try {
      final deviceId = await getDeviceId();
      final docId = '${email}_$deviceId';
      await _firestore.collection(_collectionName).doc(docId).update({
        'lastAccess': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> requestActivation(String email) async {
    final deviceId = await getDeviceId();

    // Look up this exact email+device pair directly by its document id.
    // We never search/match by deviceId alone: a deviceId collision with
    // a *different* email must never delete or touch that other account.
    final docId = '${email}_$deviceId';
    final docRef = _firestore.collection(_collectionName).doc(docId);

    final existingDoc = await docRef.get();
    if (existingDoc.exists) {
      await docRef.update({
        'lastRequestDate': FieldValue.serverTimestamp(),
        'lastAccess': FieldValue.serverTimestamp(),
      });
      return;
    }

    late final Map<String, dynamic> deviceInfo;
    late final String? ipAddress;
    late final Position? position;

    await Future.wait([
      _getDeviceInfo().then((value) => deviceInfo = value),
      _getIpAddress().then((value) => ipAddress = value),
      _getLocation().then((value) => position = value),
    ]);

    final data = {
      'deviceId': deviceId,
      'email': email,
      'deviceInfo': deviceInfo,
      'ipAddress': ipAddress,
      'location': position != null
          ? {'latitude': position?.latitude, 'longitude': position?.longitude}
          : null,
      'isApproved': false,
      'requestDate': FieldValue.serverTimestamp(),
      'lastAccess': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
  }
}
