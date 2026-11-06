import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:digipad_flutter/screens/features/measurements/measurement_capture_screen.dart';
import 'package:digipad_flutter/screens/features/measurements/measurements_list_screen.dart';
import 'package:digipad_flutter/screens/features/measurements/optical_editor_screen.dart';
import 'package:digipad_flutter/screens/features/measurements/optical_logic_controller.dart';

class MeasurementHubScreen extends StatefulWidget {
  const MeasurementHubScreen({super.key});

  @override
  State<MeasurementHubScreen> createState() => _MeasurementHubScreenState();
}

class _MeasurementHubScreenState extends State<MeasurementHubScreen> {
  static const Color _bg = Color(0xFF121212);

  // Flagged for later: hidden from the hub per product decision, kept wired
  // so they can be turned back on without re-doing the capture/navigation code.
  static const bool _kShowNewMeasurementTile = false;
  // Re-enabled 2026-11-05: lets the client send a photo straight to the
  // editor without requiring the 4-marker accessory detection first.
  static const bool _kShowRemoteMeasurementTile = true;

  static const _creationParams = <String, dynamic>{
    'modelPath': 'assets/model3.tflite',
    'labelPath': 'assets/labels.txt',
  };

  MethodChannel? _channel;
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('native-left-view/$id');
  }

  // ── Detection ────────────────────────────────────────────────────────────────

  List<Map<String, double>> _inflateDetections(dynamic rawList) {
    if (rawList == null) return [];
    try {
      final list = (rawList as List).map((e) => (e as num).toDouble()).toList();
      final result = <Map<String, double>>[];
      for (int i = 0; i + 1 < list.length; i += 2) {
        result.add({'x': list[i], 'y': list[i + 1]});
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> _processImagePath(String path, {double? angle}) async {
    if (_channel == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.hubDetectorNotReady),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }
    if (mounted) setState(() => _isCapturing = true);
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final result = await _channel!.invokeMethod('detectFromImage', {'path': path});
      if (!mounted) return;
      if (result != null) {
        final rawMap = Map<String, dynamic>.from(result as Map);
        final detections = {
          'circles': _inflateDetections(rawMap['circles']),
          'eyes': _inflateDetections(rawMap['eyes']),
        };
        final found = (detections['circles'] as List).length;
        setState(() => _isCapturing = false);
        if (found < 4) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.detectionIncomplete(found)),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ));
        }
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => OpticalEditorScreen(
            imagePath: path,
            detections: detections,
            pantoscopicAngle: angle,
          ),
        ));
      } else {
        if (mounted) setState(() => _isCapturing = false);
      }
    } catch (e) {
      debugPrint('Hub detection error: $e');
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // ── Gallery actions ───────────────────────────────────────────────────────────

  Future<void> _openSystemGallery() async {
    if (_isCapturing) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null || !mounted) return;
      await _processImagePath(image.path);
    } catch (e) {
      debugPrint('System gallery error: $e');
    }
  }

  // Medición remota: the client already has a photo taken WITHOUT the
  // reference accessory (sent via WhatsApp, email, etc.) — just pick it from
  // the device gallery and drop straight into the manual/no-accessory editor,
  // exactly like SharedImageIntentHandler does for images that arrive via the
  // share sheet. No live camera view and no 4-marker auto-detection here: the
  // Totem kiosk device has no camera, and there's nothing to auto-detect on
  // an accessory-less photo anyway.
  Future<void> _openRemoteMeasurement() async {
    if (_isCapturing) return;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OpticalEditorScreen(
          imagePath: image.path,
          detections: const {},
          mode: MeasurementMode.sinAccesorio,
        ),
      ));
    } catch (e) {
      debugPrint('Remote measurement gallery error: $e');
    }
  }

  void _openInternalGallery() {
    if (_isCapturing) return;
    showDialog(
      context: context,
      builder: (ctx) => InternalGalleryDialog(
        onProcessImage: (file) async {
          Navigator.of(ctx).pop();
          final angle = await GalleryStorage.instance.getAngle(file);
          await _processImagePath(file.path, angle: angle);
        },
      ),
    );
  }

  // ── Tile grid ────────────────────────────────────────────────────────────────

  /// 2x2 grid instead of a stacked column — each tile fills its own quarter
  /// of the available area exactly (computed from the real constraints, not
  /// a fixed aspect ratio), so tiles stay large and the icon/label inside
  /// each one scale with it (see `_HubTile`) instead of looking small inside
  /// oversized empty cards.
  Widget _buildTileGrid(BuildContext context) {
    final tiles = <Widget>[
      // Flagged off per product decision — kept for later re-activation.
      if (_kShowNewMeasurementTile)
        _HubTile(
          icon: Icons.camera_alt,
          label: context.l10n.hubNewMeasurement,
          color: Colors.deepPurpleAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MeasurementCaptureScreen()),
          ),
        ),
      _HubTile(
        icon: Icons.sd_storage_outlined,
        label: context.l10n.vmInternalGallery,
        color: Colors.tealAccent,
        onTap: _openInternalGallery,
      ),
      _HubTile(
        icon: Icons.assignment_outlined,
        label: context.l10n.myMeasurements,
        color: const Color(0xFFBB86FC),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MeasurementsListScreen()),
        ),
      ),
      _HubTile(
        icon: Icons.photo_library_outlined,
        label: context.l10n.galleryTitle,
        color: Colors.blueAccent,
        onTap: _openSystemGallery,
      ),
      // Flagged off per product decision — kept for later re-activation.
      if (_kShowRemoteMeasurementTile)
        _HubTile(
          icon: Icons.person_search_outlined,
          label: context.l10n.hubNoAccessory,
          color: Colors.orangeAccent,
          onTap: _openRemoteMeasurement,
        ),
    ];

    const spacing = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = 2;
        final rows = (tiles.length / crossAxisCount).ceil();
        final cellWidth = (constraints.maxWidth - spacing) / crossAxisCount;
        final cellHeight = (constraints.maxHeight - spacing * (rows - 1)) / rows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) => tiles[index],
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Hidden native view — detector warms up while user reads the hub ──
          Offstage(
            offstage: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: Platform.isAndroid
                  ? AndroidView(
                      viewType: 'native-left-view',
                      layoutDirection: TextDirection.ltr,
                      creationParams: _creationParams,
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: _onPlatformViewCreated,
                    )
                  : UiKitView(
                      viewType: 'native-left-view',
                      layoutDirection: TextDirection.ltr,
                      creationParams: _creationParams,
                      creationParamsCodec: const StandardMessageCodec(),
                      onPlatformViewCreated: _onPlatformViewCreated,
                    ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        context.l10n.menuMeasurements,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: _buildTileGrid(context),
                  ),
                ),
              ],
            ),
          ),

          // ── Detection overlay ─────────────────────────────────────────────────
          if (_isCapturing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.hubAnalyzing,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        // Icon/label scale off this tile's own rendered size (not a fixed
        // pixel value) so they stay proportionate whether the grid cell ends
        // up small (a phone) or large (the Totem's big screen).
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconSize = (constraints.maxHeight * 0.32).clamp(40.0, 110.0);
            final fontSize = (constraints.maxHeight * 0.09).clamp(15.0, 28.0);
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: iconSize),
                  SizedBox(height: constraints.maxHeight * 0.05),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
