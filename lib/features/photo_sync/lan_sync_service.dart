import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// LAN fallback transport for Photo Sync.
///
/// Runs **alongside** Nearby Connections and never touches it. Pure `dart:io`
/// (no extra packages, no Google Play Services, no Bluetooth, no location
/// permission). If the Totem device and the operator phone are on the same
/// Wi-Fi / LAN it will connect even when Nearby Connections cannot.
///
/// Totem side  : [startServer] → HTTP server + UDP beacon.
/// Client side : [listenForBeacons] + [probe] to locate the Totem, [upload]
///               to send a photo.
class LanSyncService {
  LanSyncService._();
  static final LanSyncService instance = LanSyncService._();

  static const int _kPortStart = 8823;
  static const int _kPortEnd = 8833;
  static const int _kBeaconPort = 8824;
  static const String _kBeaconMagic = 'DIGIPAD-TOTEM-BEACON/1';
  static const String _kPingApp = 'digipad-photosync';

  HttpServer? _server;
  RawDatagramSocket? _beaconSock;
  Timer? _beaconTimer;
  String _name = '';
  int _port = 0;

  final _fileCtrl = StreamController<LanIncomingFile>.broadcast();
  Stream<LanIncomingFile> get fileReceived => _fileCtrl.stream;

  bool get isRunning => _server != null;
  int get port => _port;

  // ───────────────────────────── TOTEM SIDE ─────────────────────────────

  /// Starts the HTTP server (first free port in [_kPortStart].._kPortEnd) and a
  /// periodic UDP broadcast beacon. Returns the reachable `http://ip:port` URLs
  /// (empty list = could not start; caller should fall back to Nearby only).
  Future<List<String>> startServer(String name) async {
    _name = name;
    if (_server != null) return currentHosts();

    HttpServer? srv;
    for (int p = _kPortStart; p <= _kPortEnd; p++) {
      try {
        srv = await HttpServer.bind(InternetAddress.anyIPv4, p, shared: true);
        _port = p;
        break;
      } catch (_) {
        // port busy — try the next one
      }
    }
    if (srv == null) {
      debugPrint('[LanSync] could not bind any port $_kPortStart-$_kPortEnd');
      return const [];
    }

    _server = srv;
    srv.listen(
      _handleRequest,
      onError: (e) => debugPrint('[LanSync] server error: $e'),
      cancelOnError: false,
    );
    _startBeacon();

    final hosts = await currentHosts();
    debugPrint('[LanSync] server up on port $_port — hosts: $hosts');
    return hosts;
  }

  Future<void> stopServer() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    try {
      _beaconSock?.close();
    } catch (_) {}
    _beaconSock = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = 0;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final path = req.uri.path;

      if (req.method == 'GET' && (path == '/ping' || path == '/')) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..headers.set('Access-Control-Allow-Origin', '*')
          ..write(jsonEncode({'app': _kPingApp, 'name': _name, 'port': _port}));
        await req.response.close();
        return;
      }

      if (req.method == 'POST' && path == '/upload') {
        final bytes = await _collectBody(req);
        final h = req.headers;
        final name = _hdr(h, 'x-photo-name') ??
            'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

        double? asNum(String key) {
          final v = _hdr(h, key);
          return v == null ? null : double.tryParse(v);
        }

        // The bytes are handed to the caller, which owns disk persistence
        // (it has path_provider; this service stays storage-agnostic).
        _fileCtrl.add(LanIncomingFile(
          bytes: Uint8List.fromList(bytes),
          fileName: name,
          angle: asNum('x-angle'),
          frameWidthMm: asNum('x-frame-width-mm'),
          patientFirstName: _hdr(h, 'x-patient-first'),
          patientLastName: _hdr(h, 'x-patient-last'),
          captureDate: _hdr(h, 'x-capture-date'),
        ));

        req.response
          ..statusCode = 200
          ..write('OK');
        await req.response.close();
        return;
      }

      req.response
        ..statusCode = 404
        ..write('not found');
      await req.response.close();
    } catch (e) {
      debugPrint('[LanSync] request handling error: $e');
      try {
        req.response.statusCode = 500;
        await req.response.close();
      } catch (_) {}
    }
  }

  /// All non-loopback IPv4 `http://ip:port` URLs this device can be reached on.
  Future<List<String>> currentHosts() async {
    if (_port == 0) return const [];
    final out = <String>[];
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final ni in ifaces) {
        for (final addr in ni.addresses) {
          if (addr.isLoopback) continue;
          out.add('http://${addr.address}:$_port');
        }
      }
    } catch (e) {
      debugPrint('[LanSync] interface enumeration failed: $e');
    }
    return out;
  }

  void _startBeacon() {
    _beaconTimer?.cancel();
    RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((sock) {
      _beaconSock = sock..broadcastEnabled = true;
      _beaconTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_server == null) return;
        final msg = utf8.encode('$_kBeaconMagic\n$_name\n$_port');
        try {
          sock.send(msg, InternetAddress('255.255.255.255'), _kBeaconPort);
        } catch (_) {}
      });
    }).catchError((e) {
      debugPrint('[LanSync] beacon socket bind failed: $e');
    });
  }

  // ───────────────────────────── CLIENT SIDE ────────────────────────────

  /// Listens for Totem UDP beacons for [window]. Returns the discovered
  /// `http://ip:port` hosts (filtered to [wantName] when it is not empty).
  Future<Set<String>> listenForBeacons(
    String wantName, {
    Duration window = const Duration(seconds: 3),
  }) async {
    final found = <String>{};
    RawDatagramSocket? sock;
    try {
      sock = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _kBeaconPort,
        reuseAddress: true,
      );
      sock.broadcastEnabled = true;
      final sub = sock.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = sock!.receive();
        if (dg == null) return;
        try {
          final parts = utf8.decode(dg.data).split('\n');
          if (parts.length >= 3 && parts[0] == _kBeaconMagic) {
            final n = parts[1].trim();
            final p = int.tryParse(parts[2].trim());
            if (p != null &&
                (wantName.isEmpty || n.isEmpty || n == wantName)) {
              found.add('http://${dg.address.address}:$p');
            }
          }
        } catch (_) {}
      });
      await Future.delayed(window);
      await sub.cancel();
    } catch (e) {
      debugPrint('[LanSync] beacon listen failed: $e');
    } finally {
      try {
        sock?.close();
      } catch (_) {}
    }
    return found;
  }

  /// `GET {host}/ping` — returns the Totem name if reachable, else `null`.
  Future<String?> probe(
    String host, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(Uri.parse('$host/ping')).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode != 200) return null;
      final body =
          await res.transform(utf8.decoder).join().timeout(timeout);
      final map = jsonDecode(body) as Map<String, dynamic>;
      if (map['app'] == _kPingApp) return (map['name'] as String?) ?? '';
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Probes every candidate host in parallel; returns the first that answers
  /// as [wantName] (or any Totem when [wantName] is empty), else `null`.
  Future<String?> firstReachable(
    Iterable<String> hosts,
    String wantName, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final list = hosts.toSet().toList();
    if (list.isEmpty) return null;
    final results = await Future.wait(list.map((h) async {
      final n = await probe(h, timeout: timeout);
      if (n == null) return null;
      if (wantName.isEmpty || n.isEmpty || n == wantName) return h;
      return null;
    }));
    for (final r in results) {
      if (r != null) return r;
    }
    return null;
  }

  /// `POST {host}/upload` with the photo bytes and metadata headers.
  Future<bool> upload(
    String host,
    File file, {
    String? fileName,
    double? angle,
    double? frameWidthMm,
    String? patientFirstName,
    String? patientLastName,
    String? captureDate,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final bytes = await file.readAsBytes();
      final req = await client.postUrl(Uri.parse('$host/upload'));
      req.headers.contentType = ContentType.binary;

      void put(String key, String? value) {
        if (value == null || value.isEmpty) return;
        req.headers.set(key, base64.encode(utf8.encode(value)));
      }

      put('x-photo-name', fileName ?? file.uri.pathSegments.last);
      put('x-angle', angle?.toString());
      put('x-frame-width-mm', frameWidthMm?.toString());
      put('x-patient-first', patientFirstName);
      put('x-patient-last', patientLastName);
      put('x-capture-date', captureDate);

      req.add(bytes);
      final res = await req.close().timeout(const Duration(seconds: 25));
      await res.drain<void>();
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[LanSync] upload failed: $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  // ───────────────────────────── helpers ───────────────────────────────

  static Future<List<int>> _collectBody(HttpRequest req) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in req) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  /// Header values are sent base64-encoded (UTF-8 safe); fall back to raw.
  static String? _hdr(HttpHeaders h, String key) {
    final v = h.value(key);
    if (v == null || v.isEmpty) return null;
    try {
      return utf8.decode(base64.decode(v));
    } catch (_) {
      return v;
    }
  }
}

/// A photo received over the LAN transport. Raw [bytes] — the receiver writes
/// them to its own storage.
class LanIncomingFile {
  final Uint8List bytes;
  final String fileName;
  final double? angle;
  final double? frameWidthMm;
  final String? patientFirstName;
  final String? patientLastName;
  final String? captureDate;

  const LanIncomingFile({
    required this.bytes,
    required this.fileName,
    this.angle,
    this.frameWidthMm,
    this.patientFirstName,
    this.patientLastName,
    this.captureDate,
  });
}
