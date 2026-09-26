import 'dart:io';
import 'dart:math' show atan2, pi, sqrt;
import 'dart:ui';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digipad_flutter/screens/features/measurements/optical_editor_screen.dart';
import 'package:digipad_flutter/screens/features/measurements/optical_logic_controller.dart';
import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:digipad_flutter/l10n/l10n.dart';

enum CaptureInitialAction { none, openSystemGallery, openInternalGallery }

class MeasurementCaptureScreen extends StatefulWidget {
  const MeasurementCaptureScreen({
    super.key,
    this.initialAction = CaptureInitialAction.none,
    this.onPhotoCaptured,
    this.mode = MeasurementMode.conAccesorio,
  });

  final CaptureInitialAction initialAction;
  final void Function(String path)? onPhotoCaptured;
  final MeasurementMode mode;

  @override
  State<MeasurementCaptureScreen> createState() =>
      _MeasurementCaptureScreenState();
}

class _MeasurementCaptureScreenState extends State<MeasurementCaptureScreen>
    with WidgetsBindingObserver {
  MethodChannel? _channel;
  final ImagePicker _picker = ImagePicker();

  late final ValueNotifier<bool> _galleryModeNotifier;

  final bool _torchEnabled = false;
  bool _frontCamera = false;

  String? _lastPhotoPath;
  bool _lastPhotoWasFront = false;
  Map<String, dynamic>? _lastPhotoDetections;

  bool _hasPermission = false;
  bool _isCheckingPermission = true;
  bool _isCapturing = false;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final ValueNotifier<double> _pantoscopicAngleNotifier = ValueNotifier(0.0);
  int _lastAccelMs = 0;
  double _angleCalibrationOffset = 0.0;
  double _smoothedAngle = 0.0;
  static const double _kAngleAlpha = 0.15;

  double _zoomLevel = 3.0;
  static const double _kZoomMin = 1.0;
  static const double _kZoomMax = 10.0;

  static const Color _backgroundColor = Color(0xFF121212);
  static const Color _accentColor = Colors.deepPurpleAccent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _galleryModeNotifier = ValueNotifier<bool>(true);

    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() {
          _angleCalibrationOffset = prefs.getDouble('angleCalibrationOffset') ?? 0.0;
          final savedZoom = prefs.getDouble('measurementZoomLevel');
          if (savedZoom != null) {
            _zoomLevel = savedZoom.clamp(_kZoomMin, _kZoomMax);
          }
        });
      }
    });

    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastAccelMs < 100) return; // ~10 fps is enough for display
      _lastAccelMs = nowMs;
      final xyMag = sqrt(event.x * event.x + event.y * event.y);
      final tilt = sqrt(event.x * event.x + event.z * event.z);
      final raw = -atan2(event.z, xyMag) * (180 / pi);
      _smoothedAngle = _kAngleAlpha * raw + (1 - _kAngleAlpha) * _smoothedAngle;
      _pantoscopicAngleNotifier.value = _smoothedAngle - _angleCalibrationOffset;
      debugPrint(
        '[PantoAngle] '
        'x=${event.x.toStringAsFixed(2)} '
        'y=${event.y.toStringAsFixed(2)} '
        'z=${event.z.toStringAsFixed(2)} | '
        'tilt=${tilt.toStringAsFixed(2)} | '
        'θ=${_pantoscopicAngleNotifier.value.toStringAsFixed(1)}°',
      );
    });

    _checkCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    _pantoscopicAngleNotifier.dispose();
    _galleryModeNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCameraPermission();
    }
  }

  Future<void> _checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (mounted) {
        setState(() {
          _hasPermission = status.isGranted;
          _isCheckingPermission = false;
        });
        if (status.isDenied) {
          await _requestCameraPermission();
        }
      }
    } catch (e) {
      debugPrint('Error checking permission: $e');
      if (mounted) setState(() => _isCheckingPermission = false);
    }
  }

  Future<void> _requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (mounted) {
        setState(() => _hasPermission = status.isGranted);
        if (status.isPermanentlyDenied) {
          _showSettingsDialog();
        }
      }
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          context.l10n.cameraRequiredTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          context.l10n.cameraRequiredContent,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: Text(
              context.l10n.openSettings,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermission) {
      return const Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(child: CircularProgressIndicator(color: _accentColor)),
      );
    }

    if (!_hasPermission) {
      return _buildPermissionRequestUI();
    }

    const viewType = 'native-left-view';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      'modelPath': 'assets/model3.tflite',
      'labelPath': 'assets/labels.txt',
    };

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _galleryModeNotifier,
          builder: (context, isGalleryOnly, child) {
            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      flex: 7,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: Stack(
                          children: [
                            if (Platform.isAndroid)
                              AndroidView(
                                viewType: viewType,
                                layoutDirection: TextDirection.ltr,
                                creationParams: creationParams,
                                creationParamsCodec:
                                    const StandardMessageCodec(),
                                onPlatformViewCreated: _onPlatformViewCreated,
                              )
                            else if (Platform.isIOS)
                              UiKitView(
                                viewType: viewType,
                                layoutDirection: TextDirection.ltr,
                                creationParams: creationParams,
                                creationParamsCodec:
                                    const StandardMessageCodec(),
                                onPlatformViewCreated: _onPlatformViewCreated,
                              )
                            else
                              Center(
                                child: Text(
                                  context.l10n.platformNotSupported,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),

                            if (isGalleryOnly)
                              Container(
                                color: _backgroundColor,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 80,
                                        color: Colors.white24,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        context.l10n.nativeSplitGalleryOnlyHint,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: _buildControlPanel(isGalleryOnly)),
                  ],
                ),
                _buildBackButton(context),
                _buildInclinometerOverlay(),
                _buildZoomSlider(),
                if (_isCapturing)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 14),
                          const Text(
                            'Analizando...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _calibrateAngleZero() async {
    final rawAngle = _pantoscopicAngleNotifier.value + _angleCalibrationOffset;
    _angleCalibrationOffset = rawAngle;
    _pantoscopicAngleNotifier.value = 0.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('angleCalibrationOffset', _angleCalibrationOffset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ángulo calibrado a 0°'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildInclinometerOverlay() {
    return Positioned(
      top: 80.0,
      right: 16.0,
      child: ValueListenableBuilder<double>(
        valueListenable: _pantoscopicAngleNotifier,
        builder: (context, angle, _) {
          final isGoodAngle = angle >= 0 && angle <= 15;
          final hasCalibration = _angleCalibrationOffset != 0.0;
          return GestureDetector(
            onLongPress: _calibrateAngleZero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isGoodAngle ? Colors.greenAccent : Colors.redAccent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.screen_rotation,
                    color: isGoodAngle ? Colors.greenAccent : Colors.redAccent,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${angle.toStringAsFixed(1)}°',
                    style: TextStyle(
                      color: isGoodAngle ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (hasCalibration)
                    Text(
                      'cal',
                      style: TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildZoomSlider() {
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
              value: _zoomLevel,
              min: _kZoomMin,
              max: _kZoomMax,
              onChanged: _applyZoom,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Positioned(
      top: 16.0,
      left: 16.0,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPlatformViewCreated(int id) async {
    _channel = MethodChannel('native-left-view/$id');
    if (mounted) _galleryModeNotifier.value = false;

    await Future.wait([
      _channel!.invokeMethod('setTorch', {'enabled': _torchEnabled}),
      _channel!.invokeMethod('setFrontCamera', {'front': _frontCamera}),
      _channel!.invokeMethod('setZoom', {'ratio': _zoomLevel}),
    ]);
  }

  void _applyZoom(double ratio) {
    setState(() => _zoomLevel = ratio.clamp(_kZoomMin, _kZoomMax));
    _channel?.invokeMethod('setZoom', {'ratio': _zoomLevel});
    SharedPreferences.getInstance().then((p) => p.setDouble('measurementZoomLevel', _zoomLevel));
  }

  List<Map<String, double>> _inflateDetections(dynamic rawList) {
    if (rawList == null) return [];
    try {
      final List<double> list = (rawList as List)
          .map((e) => (e as num).toDouble())
          .toList();
      final result = <Map<String, double>>[];
      for (int i = 0; i + 1 < list.length; i += 2) {
        result.add({'x': list[i], 'y': list[i + 1]});
      }
      return result;
    } catch (e) {
      debugPrint('[_inflateDetections] parse error: $e');
      return [];
    }
  }

  Widget _buildPermissionRequestUI() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 100, color: Colors.white24),
              const SizedBox(height: 24),
              Text(
                context.l10n.cameraPermissionRequired,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.cameraPermissionExplain,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
                onPressed: _requestCameraPermission,
                child: Text(
                  context.l10n.grantPermission,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(bool isGalleryOnly) {
    return Container(
      color: _backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPhotoButton(isGalleryOnly),
                const SizedBox(width: 32),
                _buildIconButton(
                  icon: Icons.flip_camera_ios_outlined,
                  onPressed: () {
                    setState(() => _frontCamera = !_frontCamera);
                    _channel?.invokeMethod('setFrontCamera', {'front': _frontCamera});
                  },
                  size: 40,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildLastPhotoThumbnail(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 30,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: size),
      iconSize: size + 14,
      onPressed: onPressed,
    );
  }

  Widget _buildPhotoButton(bool isGalleryOnly) {
    return SizedBox(
      width: 90,
      height: 90,
      child: ElevatedButton(
        onPressed: _isCapturing
            ? null
            : (isGalleryOnly ? () => _pickImage(ImageSource.camera) : _capturePhoto),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: Colors.white,
          side: const BorderSide(color: _accentColor, width: 4),
          padding: EdgeInsets.zero,
        ),
        child: _isCapturing
            ? const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(strokeWidth: 3, color: _accentColor),
              )
            : Icon(
                isGalleryOnly ? Icons.camera_alt : Icons.camera,
                color: _accentColor,
                size: 45,
              ),
      ),
    );
  }

  Widget _buildLastPhotoThumbnail() {
    if (_lastPhotoPath == null || _lastPhotoDetections == null) {
      return const SizedBox(width: 48, height: 48);
    }
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => OpticalEditorScreen(
              imagePath: _lastPhotoPath!,
              detections: _lastPhotoDetections!,
              isFrontCamera: _lastPhotoWasFront,
              mode: widget.mode,
            ),
          ),
        );
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white38, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(_lastPhotoPath!),
            fit: BoxFit.cover,
            cacheWidth: 144,
            key: ValueKey(_lastPhotoPath),
          ),
        ),
      ),
    );
  }

  Future<void> _processImagePath(String path, {double? angle}) async {
    if (_channel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El módulo de detección no está listo. Intenta de nuevo.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ));
      }
      return;
    }
    setState(() => _isCapturing = true);
    // Let the loading overlay render for at least one frame before blocking
    // on the native channel (especially fast on emulator).
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final result = await _channel!.invokeMethod('detectFromImage', {
        'path': path,
      });

      if (result != null) {
        final Map<String, dynamic> rawMap = Map<String, dynamic>.from(result);

        final String? nativeDebug = rawMap['_debug'] as String?;
        final Map<String, dynamic> detections = {
          'circles': _inflateDetections(rawMap['circles']),
          'eyes': _inflateDetections(rawMap['eyes']),
        };

        if (mounted) {
          final List circles = detections['circles'] as List;
          final int found = circles.length;

          setState(() {
            _lastPhotoPath = path;
            _lastPhotoWasFront = false;
            _lastPhotoDetections = detections;
            _isCapturing = false;
          });

          // Avisar si la detección fue parcial, pero siempre abrir el editor.
          // El controlador coloca puntos genéricos (tipo anteojos) para los no detectados.
          if (found < 4 && widget.mode == MeasurementMode.conAccesorio) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.detectionIncomplete(found)),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OpticalEditorScreen(
                imagePath: path,
                detections: detections,
                isFrontCamera: false,
                pantoscopicAngle: angle,
                mode: widget.mode,
                debugInfo: nativeDebug,
              ),
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isCapturing = false);
      }
    } catch (e) {
      debugPrint("Error picking/processing image: $e");
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error de detección: ${e.runtimeType}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isCapturing) return;
    // Snapshot the angle before opening the picker: for a camera shot the phone
    // is still in measurement position right now; after the system camera opens
    // orientation may change completely.
    final double? angleSnapshot = source == ImageSource.camera
        ? _pantoscopicAngleNotifier.value
        : null;
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;
      // Show loading overlay immediately before detection starts
      if (mounted) setState(() => _isCapturing = true);
      await _processImagePath(image.path, angle: angleSnapshot);
    } catch (e) {
      debugPrint("Error capturing using image picker: $e");
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    // Capture angle NOW — before the native call plays the shutter sound and
    // runs TFLite detection (which can take several hundred ms). By the time
    // the native call returns the user may have already moved the device.
    final double angleAtCapture = _pantoscopicAngleNotifier.value;

    try {
      final result = await _channel?.invokeMethod('capturePhoto');

      if (result != null && result is Map) {
        final String? nativePath = result['path'] as String?;

        if (nativePath != null) {
          final bool wasFront = _frontCamera;

          // Notify PhotoSync sender immediately (before detection)
          widget.onPhotoCaptured?.call(nativePath);

          // Run post-capture detection
          Map<String, dynamic> detectionsSnapshot = {
            'circles': <Map<String, double>>[],
            'eyes': <Map<String, double>>[],
          };
          String? captureDebug;
          try {
            final detectResult = await _channel!
                .invokeMethod('detectFromImage', {'path': nativePath});
            if (detectResult != null) {
              final rawMap = Map<String, dynamic>.from(detectResult as Map);
              captureDebug = rawMap['_debug'] as String?;
              detectionsSnapshot = {
                'circles': _inflateDetections(rawMap['circles']),
                'eyes': _inflateDetections(rawMap['eyes']),
              };
            }
          } catch (e) {
            debugPrint('Post-capture detection error: $e');
          }

          if (!mounted) return;

          final int found = (detectionsSnapshot['circles'] as List).length;

          setState(() {
            _lastPhotoPath = nativePath;
            _lastPhotoWasFront = wasFront;
            _lastPhotoDetections = detectionsSnapshot;
          });

          if (found < 4 && widget.mode == MeasurementMode.conAccesorio) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.captureFailed(found)),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OpticalEditorScreen(
                imagePath: nativePath,
                detections: detectionsSnapshot,
                isFrontCamera: wasFront,
                pantoscopicAngle: angleAtCapture,
                mode: widget.mode,
                debugInfo: captureDebug,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error capturing photo: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error de captura: ${e.runtimeType}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }
}

// ── Internal gallery dialog with real-time updates, X delete, multi-select ───

class InternalGalleryDialog extends StatefulWidget {
  final Future<void> Function(File) onProcessImage;
  const InternalGalleryDialog({super.key, required this.onProcessImage});

  @override
  State<InternalGalleryDialog> createState() => InternalGalleryDialogState();
}

class InternalGalleryDialogState extends State<InternalGalleryDialog> {
  bool _selecting = false;
  final Set<String> _selected = {};
  final Map<String, double?> _angleCache = {};

  void _enterSelect(File file) {
    setState(() {
      _selecting = true;
      _selected.add(file.path);
    });
  }

  void _toggleSelect(File file) {
    setState(() {
      if (_selected.contains(file.path)) {
        _selected.remove(file.path);
        if (_selected.isEmpty) _selecting = false;
      } else {
        _selected.add(file.path);
      }
    });
  }

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<bool> _confirmDelete(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey.shade800,
            title: Text(
              count == 1 ? '¿Eliminar foto?' : 'Eliminar $count fotos',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              count == 1
                  ? '¿Estás seguro de que querés eliminar esta foto?'
                  : '¿Eliminar las $count fotos seleccionadas?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteSingle(File file) async {
    final ok = await _confirmDelete(1);
    if (!ok || !mounted) return;
    await GalleryStorage.instance.deleteImage(file);
  }

  Future<void> _deleteSelected(List<File> allImages) async {
    final files = allImages.where((f) => _selected.contains(f.path)).toList();
    if (files.isEmpty) return;
    final ok = await _confirmDelete(files.length);
    if (!ok || !mounted) return;
    for (final f in files) {
      await GalleryStorage.instance.deleteImage(f);
    }
    _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade700),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        child: StreamBuilder<List<File>>(
          stream: GalleryStorage.instance.watchImages(),
          builder: (ctx, snap) {
            final images = snap.data ?? [];
            for (final f in images) {
              if (!_angleCache.containsKey(f.path)) {
                _angleCache[f.path] = null;
                GalleryStorage.instance.getAngle(f).then((a) {
                  if (mounted && a != null) setState(() => _angleCache[f.path] = a);
                });
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.vmInternalGallery,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (_selecting) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${_selected.length} seleccionada${_selected.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _deleteSelected(images),
                        icon: const Icon(
                          Icons.delete_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      TextButton(
                        onPressed: _exitSelect,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child:
                      snap.connectionState == ConnectionState.waiting &&
                          images.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : images.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.no_photography,
                                size: 64,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.vmNoImages,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1,
                              ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final file = images[index];
                            final isSelected = _selected.contains(file.path);
                            return GestureDetector(
                              onTap: _selecting
                                  ? () => _toggleSelect(file)
                                  : () => widget.onProcessImage(file),
                              onLongPress: _selecting
                                  ? null
                                  : () => _enterSelect(file),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected
                                      ? Border.all(
                                          color: const Color(0xFF6C63FF),
                                          width: 3,
                                        )
                                      : Border.all(
                                          color: Colors.transparent,
                                          width: 3,
                                        ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: Image.file(
                                        file,
                                        fit: BoxFit.cover,
                                        cacheWidth: 300,
                                      ),
                                    ),
                                    if (_selecting)
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF6C63FF)
                                                : Colors.black54,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white60,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 15,
                                                )
                                              : null,
                                        ),
                                      ),
                                    if (!_selecting)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _deleteSingle(file),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade900
                                                  .withValues(alpha: 0.85),
                                              shape: BoxShape.circle,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (!_selecting && _angleCache[file.path] != null)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orangeAccent
                                                .withValues(alpha: 0.9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${_angleCache[file.path]!.toStringAsFixed(1)}°',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
