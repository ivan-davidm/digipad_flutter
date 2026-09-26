import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'package:digipad_flutter/features/photo_sync/lan_sync_service.dart';
import 'package:digipad_flutter/features/photo_sync/photo_sync_capabilities.dart';
import 'package:digipad_flutter/features/photo_sync/photo_sync_preferences.dart';
import 'package:digipad_flutter/features/photo_sync/photo_sync_service.dart';
import 'client_state.dart';

enum _PairKind { lan, nearby, failed }

class _PairWin {
  final _PairKind kind;
  final String? host;
  final String? endpointId;
  final String? endpointName;
  const _PairWin._(this.kind, {this.host, this.endpointId, this.endpointName});
  const _PairWin.lan(String h) : this._(_PairKind.lan, host: h);
  const _PairWin.nearby(String id, String name)
      : this._(_PairKind.nearby, endpointId: id, endpointName: name);
  const _PairWin.failed() : this._(_PairKind.failed);
}

class ClientCubit extends Cubit<ClientState> {
  final PhotoSyncService _service;
  final LanSyncService _lan;
  final PhotoSyncPreferences _prefs;
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<MapEntry<String, String>>? _foundSub;
  StreamSubscription<PhotoSyncConnectionEvent>? _connSub;

  String? _targetTotemName;
  String? _connectedEndpointId;
  String? _lanHost;

  Completer<_PairWin>? _pairCompleter;
  Timer? _pairTimeout;
  bool _lanStop = false;

  ClientCubit({PhotoSyncService? service, LanSyncService? lan})
      : _service = service ?? PhotoSyncService.instance,
        _lan = lan ?? LanSyncService.instance,
        _prefs = PhotoSyncPreferences(),
        super(const ClientIdle());

  bool get _isConnected => _connectedEndpointId != null || _lanHost != null;

  void _safeEmit(ClientState s) {
    if (!isClosed) emit(s);
  }

  // ── Initialization ─────────────────────────────────────────────────────────

  Future<void> init() async {
    final savedName = await _prefs.loadLastTotemName();
    if (savedName != null && savedName.isNotEmpty) {
      await _connect(savedName, await _prefs.loadLastTotemHosts());
    } else {
      emit(const ClientScanning());
    }
  }

  // ── QR pairing ─────────────────────────────────────────────────────────────

  Future<void> pairWithToken(String token) async {
    String name;
    List<String> hosts = const [];

    const v2 = 'digipad-totem/v2 ';
    if (token.startsWith(v2)) {
      try {
        final json = jsonDecode(
          utf8.decode(base64.decode(token.substring(v2.length).trim())),
        ) as Map<String, dynamic>;
        name = (json['name'] as String?)?.trim() ?? '';
        hosts = (json['hosts'] as List?)?.map((e) => e.toString()).toList() ??
            const [];
      } catch (e) {
        debugPrint('[ClientCubit] bad v2 QR: $e');
        return;
      }
    } else if (token.startsWith('digipad-totem:')) {
      name = token.substring('digipad-totem:'.length).trim();
    } else {
      name = token.trim();
    }
    if (name.isEmpty) return;
    await _connect(name, hosts);
  }

  // ── Connect (LAN-first, Nearby in parallel, timeout) ──────────────────────

  Future<void> _connect(String name, List<String> qrHosts) async {
    _targetTotemName = name;
    _connectedEndpointId = null;
    _lanHost = null;
    _lanStop = false;
    emit(ClientDiscovering(targetName: name));

    await PhotoSyncCapabilities.acquireMulticastLock();

    final granted = await _service.requestPermissions();
    final myName = await _prefs.getOrCreateClientName();

    final completer = Completer<_PairWin>();
    _pairCompleter = completer;
    _pairTimeout?.cancel();
    _pairTimeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) completer.complete(const _PairWin.failed());
    });

    unawaited(_runLanProbe(name, qrHosts, completer));

    _connSub?.cancel();
    _foundSub?.cancel();
    if (granted) {
      _connSub = _service.connectionEvents.listen((event) {
        if (event.isConnected && !completer.isCompleted) {
          completer.complete(
            _PairWin.nearby(event.endpointId, event.endpointName),
          );
        } else if (!event.isConnected) {
          _onConnectionLost(event);
        }
      });
      _foundSub = _service.endpointFound.listen((entry) async {
        if (entry.value == _targetTotemName && !completer.isCompleted) {
          await _service.stopDiscovery();
          await _service.requestConnection(myName, entry.key);
        }
      });
      await _service.startDiscovery(myName);
    }

    final win = await completer.future;
    _pairCompleter = null;
    _pairTimeout?.cancel();
    _lanStop = true;
    _foundSub?.cancel();
    _foundSub = null;
    await _service.stopDiscovery();
    unawaited(PhotoSyncCapabilities.releaseMulticastLock());

    switch (win.kind) {
      case _PairKind.lan:
        _lanHost = win.host;
        _connSub?.cancel();
        _connSub = null;
        await _prefs.saveLastTotemName(name);
        await _prefs.saveLastTotemHosts([win.host!]);
        _safeEmit(ClientConnected(
          endpointId: 'lan',
          endpointName: name,
          transport: 'wifi',
        ));
        break;
      case _PairKind.nearby:
        _connectedEndpointId = win.endpointId;
        _connSub?.cancel();
        _connSub = _service.connectionEvents.listen(_onConnectionEvent);
        await _prefs.saveLastTotemName(win.endpointName!);
        _safeEmit(ClientConnected(
          endpointId: win.endpointId!,
          endpointName: win.endpointName!,
          transport: 'nearby',
        ));
        break;
      case _PairKind.failed:
        _connSub?.cancel();
        _connSub = null;
        final r = await PhotoSyncReadiness.read();
        _safeEmit(ClientError(
          'No se pudo conectar con el Tótem.',
          lastTotemName: name,
          checklist: _buildChecklist(r),
        ));
        break;
    }
  }

  Future<void> _runLanProbe(
    String name,
    List<String> qrHosts,
    Completer<_PairWin> completer,
  ) async {
    final candidates = <String>{...qrHosts};
    candidates.addAll(await _prefs.loadLastTotemHosts());
    for (var round = 0; round < 16 && !completer.isCompleted && !_lanStop; round++) {
      if (round == 0 || round % 3 == 0) {
        candidates.addAll(await _lan.listenForBeacons(
          name,
          window: Duration(seconds: round == 0 ? 3 : 2),
        ));
      }
      if (completer.isCompleted || _lanStop) return;
      final hit = await _lan.firstReachable(candidates, name,
          timeout: const Duration(seconds: 2));
      if (hit != null && !completer.isCompleted) {
        completer.complete(_PairWin.lan(hit));
        return;
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  List<String> _buildChecklist(PhotoSyncReadiness r) {
    final list = <String>[];
    if (!r.wifiOn) {
      list.add('Encendé el WiFi en este equipo y en el Tótem (misma red).');
    } else {
      list.add('El Tótem y este equipo tienen que estar en la MISMA red WiFi.');
    }
    if (!r.bluetoothOn) list.add('Encendé el Bluetooth (conexión directa).');
    if (!r.locationOn) {
      list.add('Encendé la Ubicación del dispositivo (Bluetooth la necesita).');
    }
    list.add('Verificá que el Tótem muestre "Transmitiendo".');
    list.add('Acercá los equipos (menos de 10 metros).');
    return list;
  }

  // ── Connection events ──────────────────────────────────────────────────────

  void _onConnectionEvent(PhotoSyncConnectionEvent event) {
    if (event.isConnected) {
      _connectedEndpointId = event.endpointId;
      _prefs.saveLastTotemName(event.endpointName);
      _safeEmit(ClientConnected(
        endpointId: event.endpointId,
        endpointName: event.endpointName,
        transport: 'nearby',
      ));
    } else {
      _onConnectionLost(event);
    }
  }

  void _onConnectionLost(PhotoSyncConnectionEvent event) {
    if (state is ClientConnected || state is ClientConnecting) {
      _connectedEndpointId = null;
      _safeEmit(ClientError(
        'Se perdió la conexión con el Tótem.',
        lastTotemName: _targetTotemName,
      ));
    }
  }

  // ── Send photo ─────────────────────────────────────────────────────────────

  Future<void> sendFromGallery() async {
    if (state is! ClientConnected || !_isConnected) return;
    final photo = await _picker.pickImage(source: ImageSource.gallery);
    if (photo == null || state is! ClientConnected) return;
    await _sendFile(photo.path);
  }

  Future<void> sendFile(File file) async {
    if (state is! ClientConnected || !_isConnected) return;
    await _sendFile(file.path);
  }

  Future<void> _sendFile(String filePath) async {
    final current = state;
    if (current is! ClientConnected) return;

    emit(current.copyWith(isSending: true));

    bool ok;
    if (_lanHost != null) {
      ok = await _lan.upload(
        _lanHost!,
        File(filePath),
        fileName: File(filePath).uri.pathSegments.last,
      );
    } else if (_connectedEndpointId != null) {
      ok = await _service.sendPhoto(_connectedEndpointId!, filePath);
    } else {
      ok = false;
    }

    if (ok) {
      final newCount = current.sentCount + 1;
      emit(ClientSendSuccess(newCount));
      await Future.delayed(const Duration(milliseconds: 700));
      if (state is ClientSendSuccess) {
        emit(ClientConnected(
          endpointId: current.endpointId,
          endpointName: current.endpointName,
          sentCount: newCount,
          transport: current.transport,
        ));
      }
    } else {
      debugPrint('[ClientCubit] send failed (transport: ${current.transport})');
      emit(current.copyWith(isSending: false));
    }
  }

  // ── Disconnect / forget ────────────────────────────────────────────────────

  Future<void> forgetTotem() async {
    _lanStop = true;
    _pairTimeout?.cancel();
    unawaited(PhotoSyncCapabilities.releaseMulticastLock());
    if (_pairCompleter != null && !_pairCompleter!.isCompleted) {
      _pairCompleter!.complete(const _PairWin.failed());
    }
    _pairCompleter = null;
    final endpointId = _connectedEndpointId;
    if (endpointId != null) await _service.disconnectFrom(endpointId);
    _connectedEndpointId = null;
    _lanHost = null;
    _targetTotemName = null;
    _foundSub?.cancel();
    _connSub?.cancel();
    await _service.stopAll();
    await _prefs.clearLastTotemName();
    emit(const ClientScanning());
  }

  Future<void> retryDiscovery() async {
    final name = _targetTotemName;
    if (name != null) {
      await _connect(name, await _prefs.loadLastTotemHosts());
    } else {
      emit(const ClientScanning());
    }
  }

  @override
  Future<void> close() async {
    _lanStop = true;
    _pairTimeout?.cancel();
    if (_pairCompleter != null && !_pairCompleter!.isCompleted) {
      _pairCompleter!.complete(const _PairWin.failed());
    }
    _pairCompleter = null;
    _foundSub?.cancel();
    _connSub?.cancel();
    unawaited(PhotoSyncCapabilities.releaseMulticastLock());
    await _service.stopAll();
    return super.close();
  }
}
