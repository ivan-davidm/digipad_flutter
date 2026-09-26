import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:path_provider/path_provider.dart';

import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/features/photo_sync/lan_sync_service.dart';
import 'package:digipad_flutter/features/photo_sync/photo_sync_preferences.dart';
import 'package:digipad_flutter/features/photo_sync/photo_sync_service.dart';
import 'totem_state.dart';

class TotemCubit extends Cubit<TotemState> {
  final GalleryStorage _storage;
  final PhotoSyncService _service;
  final LanSyncService _lan;
  final PhotoSyncPreferences _prefs;

  StreamSubscription<PhotoSyncConnectionEvent>? _connSub;
  StreamSubscription<PhotoSyncFile>? _fileSub;
  StreamSubscription<LanIncomingFile>? _lanFileSub;

  TotemCubit({
    required GalleryStorage storage,
    PhotoSyncService? service,
    LanSyncService? lan,
  }) : _storage = storage,
       _service = service ?? PhotoSyncService.instance,
       _lan = lan ?? LanSyncService.instance,
       _prefs = PhotoSyncPreferences(),
       super(const TotemIdle());

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<void> startTotem() async {
    if (state is TotemActive) return;
    emit(const TotemStarting());

    // Permissions never block the LAN transport (it needs none); they only
    // gate Nearby Connections. We request them but tolerate a partial grant.
    final granted = await _service.requestPermissions();

    await _storage.init();

    _connSub?.cancel();
    _connSub = _service.connectionEvents.listen(_onConnectionEvent);

    _fileSub?.cancel();
    _fileSub = _service.fileReceived.listen(_onNearbyFileReceived);

    _lanFileSub?.cancel();
    _lanFileSub = _lan.fileReceived.listen(_onLanFileReceived);

    final name = await _prefs.getOrCreateTotemName();

    // ── Transport 1: Nearby Connections (unchanged behaviour) ──────────────
    bool nearbyOk = false;
    if (granted) {
      nearbyOk = await _service.startAdvertising(name);
    } else {
      debugPrint('[TotemCubit] permissions partial — skipping Nearby advertise');
    }

    // ── Transport 2: LAN HTTP + UDP beacon (always attempted) ──────────────
    List<String> lanHosts = const [];
    try {
      lanHosts = await _lan.startServer(name);
    } catch (e) {
      debugPrint('[TotemCubit] LAN server start failed: $e');
    }

    if (!nearbyOk && lanHosts.isEmpty) {
      emit(const TotemError(
        'No se pudo iniciar el Tótem.\n\n'
        'Verificá que el dispositivo tenga:\n'
        '• WiFi encendido (misma red que los operadores), o\n'
        '• Bluetooth + Ubicación encendidos\n\n'
        'y que los permisos de la app estén concedidos.',
      ));
      return;
    }

    final images = await _storage.loadImages();
    emit(TotemActive(
      totemName: name,
      photoCount: images.length,
      nearbyOk: nearbyOk,
      lanHosts: lanHosts,
      lanPort: _lan.port,
    ));
  }

  // ── Stop ───────────────────────────────────────────────────────────────────

  Future<void> stopTotem() async {
    _connSub?.cancel();
    _fileSub?.cancel();
    _lanFileSub?.cancel();
    await _service.stopAll();
    await _lan.stopServer();
    emit(const TotemIdle());
  }

  // ── Connection events (Nearby) ─────────────────────────────────────────────

  void _onConnectionEvent(PhotoSyncConnectionEvent event) {
    final current = state;
    if (current is! TotemActive) return;
    final clients = List<String>.from(current.connectedClientIds);
    if (event.isConnected) {
      if (!clients.contains(event.endpointId)) clients.add(event.endpointId);
    } else {
      clients.remove(event.endpointId);
    }
    emit(current.copyWith(connectedClientIds: clients));
  }

  // ── Incoming files ─────────────────────────────────────────────────────────

  Future<void> _onNearbyFileReceived(PhotoSyncFile file) async {
    try {
      final destPath = await _newDestPath(file.fileName);
      // file.tempPath is a content:// URI on Android 10+.
      await Nearby().copyFileAndDeleteOriginal(file.tempPath, destPath);
      await _persist(
        File(destPath),
        angle: file.angle,
        patientFirstName: file.patientFirstName,
        patientLastName: file.patientLastName,
        captureDate: file.captureDate,
      );
    } catch (e) {
      debugPrint('[TotemCubit] Error saving Nearby file: $e');
    }
  }

  Future<void> _onLanFileReceived(LanIncomingFile file) async {
    try {
      final destPath = await _newDestPath(file.fileName);
      await File(destPath).writeAsBytes(file.bytes, flush: true);
      await _persist(
        File(destPath),
        angle: file.angle,
        patientFirstName: file.patientFirstName,
        patientLastName: file.patientLastName,
        captureDate: file.captureDate,
      );
    } catch (e) {
      debugPrint('[TotemCubit] Error saving LAN file: $e');
    }
  }

  Future<String> _newDestPath(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final syncDir = Directory('${dir.path}/totem_received');
    if (!await syncDir.exists()) await syncDir.create(recursive: true);
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    return '${syncDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  Future<void> _persist(
    File file, {
    double? angle,
    String? patientFirstName,
    String? patientLastName,
    String? captureDate,
  }) async {
    await _storage.saveImageWithAngle(
      file,
      angle,
      patientFirstName: patientFirstName,
      patientLastName: patientLastName,
      captureDate: captureDate,
    );
    final current = state;
    if (current is TotemActive) {
      emit(current.copyWith(photoCount: current.photoCount + 1));
    }
  }

  @override
  Future<void> close() async {
    await stopTotem();
    return super.close();
  }
}
