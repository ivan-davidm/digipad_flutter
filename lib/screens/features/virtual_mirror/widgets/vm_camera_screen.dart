import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VmCameraScreen extends StatefulWidget {
  const VmCameraScreen({super.key});

  @override
  State<VmCameraScreen> createState() => _VmCameraScreenState();
}

class _VmCameraScreenState extends State<VmCameraScreen>
    with WidgetsBindingObserver {
  static const String _kZoomPrefsKey = 'vmCameraZoomLevel';
  static const String _kCalibrationPrefsKey = 'angleCalibrationOffset';

  CameraController? _controller;
  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  bool _isInitializingCamera = false;
  bool _isCapturing = false;
  String? _cameraError;

  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _pendingZoom = 1.0;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  final ValueNotifier<double> _pantoscopicAngleNotifier = ValueNotifier(0.0);
  int _lastAccelMs = 0;
  double _angleCalibrationOffset = 0.0;
  double _smoothedAngle = 0.0;
  static const double _kAngleAlpha = 0.15;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _listenAccelerometer();
    _checkCameraPermission();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _angleCalibrationOffset = prefs.getDouble(_kCalibrationPrefsKey) ?? 0.0;
    _pendingZoom = prefs.getDouble(_kZoomPrefsKey) ?? 1.0;
  }

  void _listenAccelerometer() {
    _accelSub = accelerometerEventStream().listen(
      (event) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - _lastAccelMs < 100) return;
        _lastAccelMs = nowMs;
        final xyMag = math.sqrt(event.x * event.x + event.y * event.y);
        final raw = -math.atan2(event.z, xyMag) * (180 / math.pi);
        _smoothedAngle = _kAngleAlpha * raw + (1 - _kAngleAlpha) * _smoothedAngle;
        _pantoscopicAngleNotifier.value = _smoothedAngle - _angleCalibrationOffset;
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (!mounted) return;
    setState(() {
      _hasPermission = status.isGranted;
      _isCheckingPermission = false;
    });
    if (status.isGranted) {
      await _initCamera();
    } else if (status.isDenied || status.isRestricted) {
      await _requestCameraPermission();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _hasPermission = status.isGranted);
    if (status.isGranted) {
      await _initCamera();
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(context.l10n.vmCameraPermissionTitle, style: const TextStyle(color: Colors.white)),
        content: Text(
          context.l10n.vmCameraPermissionBody,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: Text(context.l10n.vmOpenSettings, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _initCamera() async {
    if (_isInitializingCamera) return;
    _isInitializingCamera = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = context.l10n.vmNoCameraFound);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.max,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await controller.initialize();
      if (!mounted) { await controller.dispose(); return; }
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final defaultZoom = _pendingZoom.clamp(minZoom, maxZoom);
      setState(() {
        _controller = controller;
        _cameraError = null;
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = defaultZoom;
        _baseZoom = defaultZoom;
      });
      await controller.setZoomLevel(defaultZoom);
    } catch (e) {
      if (mounted) setState(() => _cameraError = context.l10n.vmCameraInitError);
    } finally {
      _isInitializingCamera = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_isCapturing) return;
      if (controller != null) { _controller = null; controller.dispose(); }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && _hasPermission) _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelSub?.cancel();
    _pantoscopicAngleNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _calibrateAngleZero() async {
    final rawAngle = _pantoscopicAngleNotifier.value + _angleCalibrationOffset;
    _angleCalibrationOffset = rawAngle;
    _pantoscopicAngleNotifier.value = 0.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kCalibrationPrefsKey, _angleCalibrationOffset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.vmAngleCalibrated),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final xfile = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(xfile.path));
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.vmCaptureError),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  void _applyZoom(double ratio) {
    final clamped = ratio.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = clamped);
    _controller?.setZoomLevel(clamped);
    SharedPreferences.getInstance().then((p) => p.setDouble(_kZoomPrefsKey, clamped));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildCameraPreview(),
            _buildBackButton(),
            if (_hasPermission) _buildInclinometerOverlay(),
            if (_hasPermission) _buildZoomSlider(),
            if (_hasPermission && _controller != null) _buildShutterButton(),
            if (_isCapturing) _buildCapturingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isCheckingPermission) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }
    if (!_hasPermission) return _buildPermissionUI();
    if (_cameraError != null) return _buildErrorUI(_cameraError!);
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
    }
    return GestureDetector(
      onScaleStart: (_) { _baseZoom = _currentZoom; },
      onScaleUpdate: (details) {
        final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
        if ((newZoom - _currentZoom).abs() > 0.01) _applyZoom(newZoom);
      },
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 80, color: Colors.white24),
            const SizedBox(height: 24),
            Text(context.l10n.vmCameraAccessNeededTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(context.l10n.vmCameraAccessNeededBody,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 28),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
              onPressed: _requestCameraPermission,
              child: Text(context.l10n.vmGivePermission, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
              onPressed: _initCamera,
              child: Text(context.l10n.photoSyncRetry, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: 8,
      left: 12,
      child: Container(
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white60, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Widget _buildZoomSlider() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return const SizedBox.shrink();
    return Positioned(
      top: 170.0,
      right: 0.0,
      child: RotatedBox(
        quarterTurns: 3,
        child: SizedBox(
          width: 280,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.amber,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.amber,
              overlayColor: Colors.amber.withValues(alpha: 0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _currentZoom,
              min: _minZoom,
              max: _maxZoom,
              onChanged: _applyZoom,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInclinometerOverlay() {
    return Positioned(
      top: 80.0,
      right: 16.0,
      child: ValueListenableBuilder<double>(
        valueListenable: _pantoscopicAngleNotifier,
        builder: (context, angle, _) {
          final isGoodAngle = angle >= 0 && angle <= 15;
          final color = isGoodAngle ? Colors.greenAccent : Colors.redAccent;
          return GestureDetector(
            onLongPress: _calibrateAngleZero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.screen_rotation, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text('${angle.toStringAsFixed(1)}°',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (_angleCalibrationOffset != 0.0)
                    Text(context.l10n.vmCalibratedAbbr,
                        style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 9)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShutterButton() {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 76,
          height: 76,
          child: ElevatedButton(
            onPressed: _isCapturing ? null : _capturePhoto,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.deepPurpleAccent, width: 4),
              padding: EdgeInsets.zero,
            ),
            child: _isCapturing
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 3, color: Colors.deepPurpleAccent),
                  )
                : const Icon(Icons.camera_alt, color: Colors.deepPurpleAccent, size: 38),
          ),
        ),
      ),
    );
  }

  Widget _buildCapturingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
