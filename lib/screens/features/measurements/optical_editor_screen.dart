import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'dart:math' as math;
import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/data/local/measurement_storage.dart';
import 'package:digipad_flutter/data/models/measurement_record.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';

import 'optical_logic_controller.dart';
import 'optical_painter.dart';

class OpticalEditorScreen extends StatefulWidget {
  // Set to true to show the debug panel button in the AppBar.
  static const bool kShowDebugButton = false;

  final String imagePath;
  final Map<String, dynamic>? detections;
  final MeasurementRecord? savedRecord;
  final bool isFrontCamera;
  final double? pantoscopicAngle;
  final MeasurementMode mode;
  final String? debugInfo;

  const OpticalEditorScreen({
    super.key,
    required this.imagePath,
    this.detections,
    this.savedRecord,
    this.isFrontCamera = false,
    this.pantoscopicAngle,
    this.mode = MeasurementMode.conAccesorio,
    this.debugInfo,
  });

  @override
  State<OpticalEditorScreen> createState() => _OpticalEditorScreenState();
}

class _OpticalEditorScreenState extends State<OpticalEditorScreen>
    with SingleTickerProviderStateMixin {
  late OpticalController _controller;
  late File _imageFile;
  Size? _imageSize;
  int _activePointers = 0;
  final TransformationController _transformationController =
      TransformationController();
  final WidgetsToImageController _screenshotController =
      WidgetsToImageController();
  late final TextEditingController _calibrationHorizontalController;
  late final TextEditingController _calibrationVerticalController;
  late final FocusNode _calibrationHorizontalFocusNode;
  late final FocusNode _calibrationVerticalFocusNode;
  bool _isSyncingCalibrationText = false;

  MeasurementRecord? _currentRecord;
  bool _showAjustePanel = false;
  Timer? _holdTimer;
  Timer? _nudgeDismissTimer;
  late final AnimationController _nudgeAnimController;
  late final Animation<Offset> _nudgeSlide;

  double _imageRotation = 0.0;
  double _currentScale = 1.0;
  bool _highResMode = false;
  bool _isPointSelected = false;
  String? _lastSelectedId;
  bool _isDraggingPoint = false;
  BoxConstraints? _viewerConstraints;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    _controller = OpticalController();
    _controller.pantoscopicAngle = widget.pantoscopicAngle;
    _calibrationHorizontalController = TextEditingController(
      text: _formatCalibrationValue(_controller.ajusteHorizontal),
    );
    _calibrationVerticalController = TextEditingController(
      text: _formatCalibrationValue(_controller.ajusteVertical),
    );
    _calibrationHorizontalFocusNode = FocusNode();
    _calibrationVerticalFocusNode = FocusNode();
    _nudgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _nudgeSlide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _nudgeAnimController,
      curve: Curves.easeOutCubic,
    ));
    _currentRecord = widget.savedRecord;
    _controller.addListener(_syncCalibrationTextFromController);
    _controller.addListener(_onControllerChanged);
    _transformationController.addListener(_onTransformChanged);
    _loadImageAndInit();
  }

  void _onTransformChanged() {
    final s = _transformationController.value.getMaxScaleOnAxis();
    if ((s - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = s;
        if (!_highResMode && s >= 2.0) _highResMode = true;
      });
    }
  }

  void _onControllerChanged() {
    final selectedId = _controller.selectedPoint?.id;
    if (selectedId != _lastSelectedId) {
      _lastSelectedId = selectedId;
      setState(() => _isPointSelected = selectedId != null);
      if (selectedId != null) {
        _showNudge();
      } else {
        _dismissNudge();
      }
    }
  }

  void _showNudge() {
    _nudgeAnimController.forward();
    _resetNudgeDismissTimer();
  }

  void _dismissNudge() {
    _nudgeDismissTimer?.cancel();
    _nudgeAnimController.reverse();
  }

  void _resetNudgeDismissTimer() {
    _nudgeDismissTimer?.cancel();
    _nudgeDismissTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _dismissNudge();
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _nudgeDismissTimer?.cancel();
    _nudgeAnimController.dispose();
    _transformationController.removeListener(_onTransformChanged);
    _transformationController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.removeListener(_syncCalibrationTextFromController);
    _calibrationHorizontalController.dispose();
    _calibrationVerticalController.dispose();
    _calibrationHorizontalFocusNode.dispose();
    _calibrationVerticalFocusNode.dispose();
    super.dispose();
  }

  String _formatCalibrationValue(double value) {
    return value.clamp(0.9, 1.25).toStringAsFixed(3);
  }

  void _syncCalibrationTextFromController() {
    if (!mounted) return;
    if (_isSyncingCalibrationText) return;

    _isSyncingCalibrationText = true;

    try {
      if (!_calibrationHorizontalFocusNode.hasFocus) {
        final next = _formatCalibrationValue(_controller.ajusteHorizontal);
        if (_calibrationHorizontalController.text != next) {
          _calibrationHorizontalController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      }

      if (!_calibrationVerticalFocusNode.hasFocus) {
        final next = _formatCalibrationValue(_controller.ajusteVertical);
        if (_calibrationVerticalController.text != next) {
          _calibrationVerticalController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      }
    } finally {
      _isSyncingCalibrationText = false;
    }
  }

  void _applyCalibrationValue({
    required OpticalController controller,
    required bool isHorizontal,
    required String rawValue,
  }) {
    final normalized = rawValue.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) return;

    final clamped = parsed.clamp(0.9, 1.25);
    if (isHorizontal) {
      controller.setAjusteHorizontal(clamped);
    } else {
      controller.setAjusteVertical(clamped);
    }
  }

  Future<void> _loadImageAndInit() async {
    try {
      final bytes = await _imageFile.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _imageSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
          if (widget.savedRecord != null) {
            _controller.restoreFromStateJson(widget.savedRecord!.stateJson);
          } else {
            _controller.initialize(widget.detections ?? {}, _imageSize!, mode: widget.mode);
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.mode == MeasurementMode.conAccesorio) _applyAutoRotation();
          _applyAutoZoom();
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showDebugSheet() {
    final ctrl = _controller;
    final lines = <String>[
      '=== KOTLIN ===',
      widget.debugInfo ?? '(sin info nativa — galería o guardado)',
      '',
      '=== FLUTTER ===',
      'imageSize: ${_imageSize?.width.toInt()}×${_imageSize?.height.toInt()}',
      'imageRotation: ${(_imageRotation * 180 / math.pi).toStringAsFixed(2)}°',
      'mode: ${ctrl.mode.name}',
      'milimetrosPorPixel: ${ctrl.milimetrosPorPixel.toStringAsFixed(5)}',
      'pixelFactorX: ${ctrl.pixelFactorX.toStringAsFixed(5)}',
      'pixelFactorY: ${ctrl.pixelFactorY.toStringAsFixed(5)}',
      '',
      '=== PUNTOS (px) ===',
      for (final p in ctrl.points)
        '${p.type.name}: (${p.position.dx.toStringAsFixed(1)}, ${p.position.dy.toStringAsFixed(1)})',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('DEBUG', style: TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
            const SizedBox(height: 8),
            SelectableText(
              lines.join('\n'),
              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyAutoRotation() {
    Offset? refTL;
    Offset? refTR;
    Offset? refBL;
    Offset? refBR;
    Offset? pRight;
    Offset? pLeft;

    for (final p in _controller.points) {
      if (p.type == DetectionType.refTL) refTL = p.position;
      else if (p.type == DetectionType.refTR) refTR = p.position;
      else if (p.type == DetectionType.refBL) refBL = p.position;
      else if (p.type == DetectionType.refBR) refBR = p.position;
      else if (p.type == DetectionType.pupilRight) pRight = p.position;
      else if (p.type == DetectionType.pupilLeft) pLeft = p.position;
    }

    // Primary: average tilt of A bar (A1→A2) and B bar (B1→B2).
    // Fallback: pupil vector if no ref bar points are available.
    double angle;
    int count = 0;
    double sumAngle = 0;

    if (refTL != null && refTR != null) {
      sumAngle += math.atan2(refTR.dy - refTL.dy, refTR.dx - refTL.dx);
      count++;
    }
    if (refBL != null && refBR != null) {
      sumAngle += math.atan2(refBR.dy - refBL.dy, refBR.dx - refBL.dx);
      count++;
    }

    if (count > 0) {
      angle = sumAngle / count;
    } else if (pRight != null && pLeft != null) {
      angle = math.atan2(pLeft.dy - pRight.dy, pLeft.dx - pRight.dx);
      if (angle > math.pi / 2) angle -= math.pi;
      else if (angle < -math.pi / 2) angle += math.pi;
    } else {
      return;
    }

    if (angle.abs() > 0.01) {
      setState(() => _imageRotation = -angle);
      debugPrint(
        "🔄 Auto-rotation: ${(_imageRotation * 180 / math.pi).toStringAsFixed(1)}° applied",
      );
    } else {
      setState(() => _imageRotation = 0.0);
    }
  }

  void _applyAutoZoom() {
    final constraints = _viewerConstraints;
    if (constraints == null || _imageSize == null || _controller.points.isEmpty) return;

    final double scaleX = constraints.maxWidth / _imageSize!.width;
    final double scaleY = constraints.maxHeight / _imageSize!.height;
    final double imgScale = scaleX < scaleY ? scaleX : scaleY;
    final double offsetX = (constraints.maxWidth - _imageSize!.width * imgScale) / 2;
    final double offsetY = (constraints.maxHeight - _imageSize!.height * imgScale) / 2;
    final double vw = constraints.maxWidth;
    final double vh = constraints.maxHeight;
    final double cxV = vw / 2;
    final double cyV = vh / 2;
    final double cosA = math.cos(_imageRotation);
    final double sinA = math.sin(_imageRotation);

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final p in _controller.points) {
      final double ux = p.position.dx * imgScale + offsetX;
      final double uy = p.position.dy * imgScale + offsetY;
      final double dx = ux - cxV;
      final double dy = uy - cyV;
      final double rx = dx * cosA - dy * sinA + cxV;
      final double ry = dx * sinA + dy * cosA + cyV;
      if (rx < minX) minX = rx;
      if (rx > maxX) maxX = rx;
      if (ry < minY) minY = ry;
      if (ry > maxY) maxY = ry;
    }

    const double pad = 16.0;
    minX -= pad;
    minY -= pad;
    maxX += pad;
    maxY += pad;

    final double bboxW = maxX - minX;
    final double bboxH = maxY - minY;
    if (bboxW <= 0 || bboxH <= 0) return;

    final double bboxCx = (minX + maxX) / 2;
    final double bboxCy = (minY + maxY) / 2;

    final double s = math.min(vw / bboxW, vh / bboxH).clamp(1.0, 5.0);
    final double tx = cxV - s * bboxCx;
    final double ty = cyV - s * bboxCy;

    _transformationController.value = Matrix4.diagonal3Values(s, s, 1.0)
      ..setTranslationRaw(tx, ty, 0.0);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _showSaveMeasurementSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.saveMeasurementDialogTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Colors.cyanAccent, size: 20),
                ),
                title: Text(context.l10n.saveToGallery,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(context.l10n.saveToGalleryDesc,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveToGallery();
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6200EE).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: Color(0xFFBB86FC), size: 20),
                ),
                title: Text(context.l10n.saveToMeasurements,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(context.l10n.saveToMeasurementsDesc,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPatientDataDialog();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    try {
      final file = File(widget.imagePath);
      await GalleryStorage.instance.saveImageWithAngle(
          file, _controller.pantoscopicAngle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.photoSavedToGallery),
            backgroundColor: Colors.teal.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
    }
  }

  void _showPatientDataDialog() {
    final firstNameCtrl = TextEditingController(
        text: _currentRecord?.patientFirstName ?? '');
    final lastNameCtrl = TextEditingController(
        text: _currentRecord?.patientLastName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          context.l10n.patientData,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.l10n.patientFirstName,
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: context.l10n.optionalHint,
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6200EE))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastNameCtrl,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.l10n.patientLastName,
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: context.l10n.optionalHint,
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF6200EE))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel,
                style: const TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6200EE)),
            onPressed: () {
              final fn = firstNameCtrl.text.trim();
              final ln = lastNameCtrl.text.trim();
              Navigator.pop(ctx);
              _saveToMeasurements(
                  firstName: fn.isEmpty ? null : fn,
                  lastName: ln.isEmpty ? null : ln);
            },
            child: Text(
              _currentRecord != null
                  ? context.l10n.updateMeasurement
                  : context.l10n.save,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToMeasurements({String? firstName, String? lastName}) async {
    try {
      // Also save to internal gallery so it's available for totem sync.
      final file = File(widget.imagePath);
      await GalleryStorage.instance.saveImageWithAngle(
          file, _controller.pantoscopicAngle);

      final now = DateTime.now();
      final id = _currentRecord?.id ??
          '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}'
          '-${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}'
          '-${now.millisecond.toString().padLeft(3, '0')}';

      final record = MeasurementRecord(
        id: id,
        imagePath: widget.imagePath,
        patientFirstName: firstName,
        patientLastName: lastName,
        createdAt: _currentRecord?.createdAt ?? now.toIso8601String(),
        stateJson: _controller.toStateJson(),
      );

      await MeasurementStorage.instance.save(record);
      if (mounted) {
        setState(() => _currentRecord = record);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.measurementSaved),
            backgroundColor: const Color(0xFF6200EE),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving measurement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSize == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: Text(
              context.l10n.exitEditionTitle,
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              context.l10n.exitEditionContent,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  context.l10n.cancel,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  context.l10n.exitLabel,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
        if ((shouldPop ?? false) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: WidgetsToImage(
          controller: _screenshotController,
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            behavior: HitTestBehavior.translucent,
            child: Scaffold(
              backgroundColor: Colors.black,
              bottomNavigationBar: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  6,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: FilledButton.icon(
                  icon: const Icon(Icons.save_alt, color: Colors.white, size: 18),
                  label: Text(
                    context.l10n.saveMeasurement,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _showSaveMeasurementSheet,
                ),
              ),
              appBar: AppBar(
                title: Text(context.l10n.measureAdjustments),
                backgroundColor: const Color(0xFF0D0D1A),
                actions: [
                  TextButton(
                    onPressed: _resetZoom,
                    child: Text(
                      context.l10n.resetZoom,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _showResultsSheet,
                    tooltip: context.l10n.shareResults,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _showAjustePanel
                          ? Colors.orangeAccent
                          : Colors.white,
                    ),
                    onPressed: () =>
                        setState(() => _showAjustePanel = !_showAjustePanel),
                    tooltip: context.l10n.calibration,
                  ),
                  if (OpticalEditorScreen.kShowDebugButton)
                    IconButton(
                      icon: const Icon(Icons.bug_report_outlined, color: Colors.yellowAccent),
                      onPressed: _showDebugSheet,
                      tooltip: 'Debug',
                    ),
                ],
              ),
              body: Column(
                children: [
                  _buildTopControls(),
                  if (_showAjustePanel) _buildCalibrationPanel(),
                  Expanded(
                    child: Stack(
                      children: [_buildImageViewer(), _buildNudgeControls()],
                    ),
                  ),
                  _buildInfoPanel(),
                ],
              ),
            ), // Scaffold
          ), // GestureDetector
        ), // WidgetsToImage
      ), // ChangeNotifierProvider
    ); // PopScope
  }

  Widget _buildImageViewer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewerConstraints = constraints;
        final double scaleX = constraints.maxWidth / _imageSize!.width;
        final double scaleY = constraints.maxHeight / _imageSize!.height;
        final double scale = scaleX < scaleY ? scaleX : scaleY;
        final double offsetX =
            (constraints.maxWidth - _imageSize!.width * scale) / 2;
        final double offsetY =
            (constraints.maxHeight - _imageSize!.height * scale) / 2;

        // Allow pan when in move mode OR when zoomed in without a point selected.
        final bool canPan = _currentScale > 1.01 && !_isPointSelected;

        return InteractiveViewer(
          transformationController: _transformationController,
          maxScale: 5.0,
          minScale: 1.0,
          panEnabled: canPan,
          scaleEnabled: true,
          child: Transform.rotate(
            angle: _imageRotation,
            alignment: Alignment.center,
            child: _buildImageContent(constraints, scale, offsetX, offsetY),
          ),
        );
      },
    );
  }

  Widget _buildImageContent(
    BoxConstraints constraints,
    double scale,
    double offsetX,
    double offsetY,
  ) {
    return Listener(
      onPointerDown: (e) {
        _activePointers++;
        if (_activePointers == 1) {
          // e.localPosition is already in image-aligned space because this
          // Listener is inside Transform.rotate — Flutter applies the inverse
          // rotation before delivering the event to children.
          _controller.handleTap(
            e.localPosition,
            scale,
            Offset(offsetX, offsetY),
            rotation: _imageRotation,
          );
        }
      },
      onPointerMove: (e) {
        // Only drag a point when exactly 1 finger AND a point is selected.
        // 2-finger gestures go to InteractiveViewer for pinch/pan.
        if (_activePointers == 1 && _controller.selectedPoint != null) {
          // e.delta is also in image-aligned space — no unrotation needed.
          _controller.handleDrag(e.delta, scale);
          _showNudge(); // keep joystick visible while dragging; re-shows if already dismissed
          if (!_isDraggingPoint) setState(() => _isDraggingPoint = true);
        }
      },
      onPointerUp: (_) {
        if (_activePointers > 0) _activePointers--;
        if (_isDraggingPoint) setState(() => _isDraggingPoint = false);
      },
      onPointerCancel: (_) {
        if (_activePointers > 0) _activePointers--;
        if (_isDraggingPoint) setState(() => _isDraggingPoint = false);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Image(
              key: ValueKey(_highResMode),
              image: ResizeImage(
                FileImage(_imageFile),
                width: _highResMode ? 1920 : 1080,
              ),
              fit: BoxFit.contain,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          ),
          // Only this painter rebuilds when controller notifies (points move, etc.)
          ListenableBuilder(
            listenable: _controller,
            builder: (_, _) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: OpticalPainter(
                rotation: _imageRotation,
                points: _controller.points,
                selectedPoint: _controller.selectedPoint,
                scale: scale,
                offset: Offset(offsetX, offsetY),
                showCircles: _controller.showCircles,
                refDiameterMmRight: _controller.referenceCircleDiameterRight,
                refDiameterMmLeft: _controller.referenceCircleDiameterLeft,
                calcRadiusPxR: _controller.calcRadiusPxRight,
                calcRadiusPxL: _controller.calcRadiusPxLeft,
                pixelFactorX: _controller.pixelFactorX,
                pixelFactorY: _controller.pixelFactorY,
                isBifocal: _controller.isBifocal,
                bifocalOffset: _controller.bifocalLineOffset,
                isDragging: _isDraggingPoint,
                dnpRight: _controller.dnpRight,
                dnpLeft: _controller.dnpLeft,
                altRight: _controller.altRight,
                altLeft: _controller.altLeft,
                aroAnc: _controller.aroAnc,
                aroAlt: _controller.aroAlt,
                anchoExtArmazon: _controller.anchoExtArmazon,
                di: _controller.di,
                puente: _controller.puente,
                diametroRight: _controller.diametroRight,
                diametroLeft: _controller.diametroLeft,
                altSupRight: _controller.altSupRight,
                altSupLeft: _controller.altSupLeft,
                showChips: _controller.showChips,
                isSinAccesorio: _controller.mode == MeasurementMode.sinAccesorio,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    final double ts = _textScale(context);
    return Container(
      height: 80 * ts,
      color: const Color(0xFF0D0D1A),
      child: Consumer<OpticalController>(
        builder: (context, ctrl, _) => Column(
          children: [
            Row(
              children: [
                Checkbox(
                  value: ctrl.showCircles,
                  activeColor: Colors.cyanAccent,
                  onChanged: (v) => ctrl.toggleCircles(v!),
                ),
                Text(
                  context.l10n.guides,
                  style: TextStyle(color: Colors.white, fontSize: 12 * ts),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    ctrl.showChips ? Icons.straighten : Icons.straighten_outlined,
                    color: ctrl.showChips ? Colors.amber : Colors.white38,
                    size: 20,
                  ),
                  tooltip: context.l10n.cleanView,
                  onPressed: () => ctrl.toggleChips(!ctrl.showChips),
                ),
                Switch(
                  value: ctrl.isBifocal,
                  activeThumbColor: Colors.orangeAccent,
                  onChanged: (v) => ctrl.toggleBifocal(v),
                ),
                if (ctrl.isBifocal) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white),
                    onPressed: () => ctrl.adjustBifocalLine(-5),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white,
                    ),
                    onPressed: () => ctrl.adjustBifocalLine(5),
                  ),
                ],
              ],
            ),
            if (ctrl.showCircles && !ctrl.showChips)
              Expanded(
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            "👁️ ${context.l10n.rightEyeP1}:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11 * ts,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: ctrl.referenceCircleDiameterRight,
                              min: 40,
                              max: 80,
                              divisions: 40,
                              activeColor: Colors.cyanAccent,
                              onChanged: (v) =>
                                  ctrl.setReferenceDiameterRight(v),
                            ),
                          ),
                          Text(
                            "${ctrl.referenceCircleDiameterRight.round()}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11 * ts,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            "👁️ ${context.l10n.leftEyeP2}:",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11 * ts,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: ctrl.referenceCircleDiameterLeft,
                              min: 40,
                              max: 80,
                              divisions: 40,
                              activeColor: Colors.greenAccent,
                              onChanged: (v) =>
                                  ctrl.setReferenceDiameterLeft(v),
                            ),
                          ),
                          Text(
                            "${ctrl.referenceCircleDiameterLeft.round()}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11 * ts,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationPanel() {
    final double ts = _textScale(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFF111128),
      child: Consumer<OpticalController>(
        builder: (context, ctrl, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Calibración de dispositivo — H/V, persiste, no tocar una vez ajustado ──
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: false,
                iconColor: Colors.white30,
                collapsedIconColor: Colors.white30,
                title: Text(
                  '${context.l10n.calibration}  '
                  'H: ${ctrl.ajusteHorizontal.toStringAsFixed(2)}  '
                  'V: ${ctrl.ajusteVertical.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white38, fontSize: 12 * ts),
                ),
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 110 * ts,
                        child: Text(
                          context.l10n.horizontalAdjustment,
                          style: TextStyle(color: Colors.white70, fontSize: 12 * ts),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: ctrl.ajusteHorizontal,
                          min: 0.9,
                          max: 1.25,
                          divisions: 350,
                          activeColor: Colors.cyanAccent,
                          onChanged: (v) => ctrl.setAjusteHorizontal(v),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _calibrationHorizontalController,
                          focusNode: _calibrationHorizontalFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 11 * ts),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.cyanAccent),
                            ),
                          ),
                          onSubmitted: (value) => _applyCalibrationValue(
                            controller: ctrl,
                            isHorizontal: true,
                            rawValue: value,
                          ),
                          onEditingComplete: () => _applyCalibrationValue(
                            controller: ctrl,
                            isHorizontal: true,
                            rawValue: _calibrationHorizontalController.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 110 * ts,
                        child: Text(
                          context.l10n.verticalAdjustment,
                          style: TextStyle(color: Colors.white70, fontSize: 12 * ts),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: ctrl.ajusteVertical,
                          min: 0.9,
                          max: 1.25,
                          divisions: 350,
                          activeColor: Colors.greenAccent,
                          onChanged: (v) => ctrl.setAjusteVertical(v),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _calibrationVerticalController,
                          focusNode: _calibrationVerticalFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 11 * ts),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.greenAccent),
                            ),
                          ),
                          onSubmitted: (value) => _applyCalibrationValue(
                            controller: ctrl,
                            isHorizontal: false,
                            rawValue: value,
                          ),
                          onEditingComplete: () => _applyCalibrationValue(
                            controller: ctrl,
                            isHorizontal: false,
                            rawValue: _calibrationVerticalController.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNudgeControls() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: SlideTransition(
        position: _nudgeSlide,
        child: AnimatedBuilder(
          animation: _nudgeAnimController,
          builder: (context, child) {
            if (_nudgeAnimController.isDismissed) return const SizedBox.shrink();
            return child!;
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _arrowButton(Icons.keyboard_arrow_left, () {
                  _controller.nudgeSelectedPoint(-1, 0);
                  _resetNudgeDismissTimer();
                }),
                const SizedBox(width: 4),
                _arrowButton(Icons.keyboard_arrow_up, () {
                  _controller.nudgeSelectedPoint(0, -1);
                  _resetNudgeDismissTimer();
                }),
                const SizedBox(width: 4),
                _arrowButton(Icons.keyboard_arrow_down, () {
                  _controller.nudgeSelectedPoint(0, 1);
                  _resetNudgeDismissTimer();
                }),
                const SizedBox(width: 4),
                _arrowButton(Icons.keyboard_arrow_right, () {
                  _controller.nudgeSelectedPoint(1, 0);
                  _resetNudgeDismissTimer();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback action) {
    return GestureDetector(
      onTapDown: (_) {
        action();
        _holdTimer = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => action(),
        );
      },
      onTapUp: (_) => _holdTimer?.cancel(),
      onTapCancel: () => _holdTimer?.cancel(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.grey[800]!.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Consumer<OpticalController>(
      builder: (context, ctrl, _) {
        final s = MediaQuery.of(context).size;
        final fs = (s.shortestSide * 0.028).clamp(10.0, 15.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ctrl.mode == MeasurementMode.sinAccesorio)
              _buildFrameWidthField(),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0D0D1A),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              padding: EdgeInsets.symmetric(horizontal: s.width * 0.02, vertical: 4),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _eyeColumn(context, ctrl, isRight: true, fs: fs)),
                    _vDivider(),
                    Expanded(flex: 2, child: _centerColumn(context, ctrl, fs: fs)),
                    _vDivider(),
                    Expanded(child: _eyeColumn(context, ctrl, isRight: false, fs: fs)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFrameWidthField() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          labelText: context.l10n.frameWidthField,
          hintText: context.l10n.frameWidthHint,
          suffixText: 'mm',
          isDense: true,
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: const TextStyle(color: Colors.white24),
          border: const UnderlineInputBorder(),
        ),
        style: const TextStyle(color: Colors.white),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (val) {
          final normalized = val.replaceAll(',', '.');
          _controller.setFrameWidthMm(double.tryParse(normalized));
        },
      ),
    );
  }

  Widget _eyeColumn(BuildContext context, OpticalController ctrl, {required bool isRight, required double fs}) {
    final label = isRight ? context.l10n.rightEyeP1 : context.l10n.leftEyeP2;
    final dnp = isRight ? ctrl.dnpRight : ctrl.dnpLeft;
    final alt = isRight ? ctrl.altRight : ctrl.altLeft;
    final altSup = isRight ? ctrl.altSupRight : ctrl.altSupLeft;
    final diam = isRight ? ctrl.referenceCircleDiameterRight : ctrl.referenceCircleDiameterLeft;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: const Color(0xFF00BFA6), fontSize: fs, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(context.l10n.dnpShort(dnp.toStringAsFixed(1)), style: TextStyle(color: Colors.white70, fontSize: fs - 1)),
          Text(context.l10n.heightShort(alt.toStringAsFixed(1)), style: TextStyle(color: Colors.white70, fontSize: fs - 1)),
          Text(context.l10n.heightTopShort(altSup.toStringAsFixed(1)), style: TextStyle(color: Colors.white38, fontSize: fs - 2)),
          Text(context.l10n.diamShort(diam.toStringAsFixed(1)), style: TextStyle(color: Colors.white70, fontSize: fs - 1, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _centerColumn(BuildContext context, OpticalController ctrl, {required double fs}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.l10n.ipdDi, style: TextStyle(color: Colors.white38, fontSize: fs - 2)),
          Text(
            ctrl.di.toStringAsFixed(1),
            style: TextStyle(color: const Color(0xFFB5B0FF), fontSize: fs + 8, fontWeight: FontWeight.bold),
          ),
          Text(context.l10n.unitMm, style: TextStyle(color: Colors.white38, fontSize: fs - 3)),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _miniStat(context.l10n.bridge, ctrl.puente, fs),
              _miniStat(context.l10n.frameW, ctrl.aroAnc, fs),
              _miniStat(context.l10n.frameH, ctrl.aroAlt, fs),
              _miniStat(context.l10n.frameOuterW, ctrl.anchoExtArmazon, fs),
              if (ctrl.pantoscopicAngle != null)
                _miniStat(context.l10n.pantoscopicAngleShort, ctrl.pantoscopicAngle!, fs, unit: '°'),
            ],
          ),
          if (ctrl.mode == MeasurementMode.sinAccesorio && ctrl.frameWidthMm == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.frameWidthMissingWarning,
                style: TextStyle(color: Colors.orangeAccent, fontSize: fs - 3),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, double fs, {String unit = 'mm'}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.white38, fontSize: fs - 3)),
        Text('${value.toStringAsFixed(1)}$unit', style: TextStyle(color: Colors.white70, fontSize: fs - 1, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _vDivider() => const VerticalDivider(color: Colors.white12, width: 1);

  double _textScale(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide > 600 ? 1.3 : 1.0;
  }

  void _showResultsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ResultsSheet(
        controller: _controller,
        screenshotController: _screenshotController,
        pantoscopicAngle: widget.pantoscopicAngle,
      ),
    );
  }
}

class _ResultsSheet extends StatelessWidget {
  final OpticalController controller;
  final WidgetsToImageController screenshotController;
  final double? pantoscopicAngle;

  const _ResultsSheet({
    required this.controller,
    required this.screenshotController,
    this.pantoscopicAngle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "📋 ${context.l10n.measurementsResultsTitle}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _resultRow(
                  context,
                  context.l10n.ipdDi,
                  controller.di,
                  highlight: true,
                ),
                _resultRow(context, context.l10n.bridge, controller.puente),
                _resultRow(context, context.l10n.frameW, controller.aroAnc),
                _resultRow(context, context.l10n.frameH, controller.aroAlt),
                if (controller.pantoscopicAngle != null)
                  _resultRow(
                    context,
                    context.l10n.pantoscopicAngle,
                    controller.pantoscopicAngle!,
                    unit: '°',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _expandedEyeBox(
                context,
                context.l10n.rightEye,
                controller.dnpRight,
                controller.altRight,
                controller.altSupRight,
                controller.referenceCircleDiameterRight,
              ),
              const SizedBox(width: 12),
              _expandedEyeBox(
                context,
                context.l10n.leftEye,
                controller.dnpLeft,
                controller.altLeft,
                controller.altSupLeft,
                controller.referenceCircleDiameterLeft,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyToClipboard(context),
                  icon: const Icon(Icons.copy),
                  label: Text(context.l10n.copyLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _shareResults(context),
                  icon: const Icon(Icons.share),
                  label: Text(context.l10n.shareLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _expandedEyeBox(
    BuildContext context,
    String label,
    double dnp,
    double alt,
    double altSup,
    double diam,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _resultRow(
              context,
              context.l10n.dnpShort(dnp.toStringAsFixed(1)),
              dnp,
              compact: true,
            ),
            _resultRow(
              context,
              context.l10n.heightShort(alt.toStringAsFixed(1)),
              alt,
              compact: true,
            ),
            _resultRow(
              context,
              context.l10n.heightTopShort(altSup.toStringAsFixed(1)),
              altSup,
              compact: true,
            ),
            _resultRow(
              context,
              context.l10n.diamShort(diam.toStringAsFixed(1)),
              diam,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(
    BuildContext context,
    String label,
    double value, {
    bool highlight = false,
    bool compact = false,
    String unit = '',
  }) {
    final displayUnit = unit.isEmpty ? context.l10n.unitMm : unit;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 12 : 14,
            ),
          ),
          Text(
            "${value.toStringAsFixed(1)} $displayUnit",
            style: TextStyle(
              color: highlight ? Colors.cyanAccent : Colors.white,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getResultsText(BuildContext context) {
    final buffer = StringBuffer()
      ..writeln(context.l10n.measurementsResultsTitle)
      ..writeln(
        "${context.l10n.ipdDi}: ${controller.di.toStringAsFixed(1)} ${context.l10n.unitMm}",
      );

    if (controller.pantoscopicAngle != null) {
      buffer.writeln(
        "${context.l10n.pantoscopicAngle}: ${controller.pantoscopicAngle!.toStringAsFixed(1)} °",
      );
    }

    buffer
      ..writeln(
        "${context.l10n.bridge}: ${controller.puente.toStringAsFixed(1)} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.frameW}: ${controller.aroAnc.toStringAsFixed(1)} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.frameH}: ${controller.aroAlt.toStringAsFixed(1)} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.frameOuterW}: ${controller.anchoExtArmazon.toStringAsFixed(1)} ${context.l10n.unitMm}",
      )
      ..writeln()
      ..writeln("${context.l10n.rightEye}:")
      ..writeln(
        "${context.l10n.dnpShort(controller.dnpRight.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.heightShort(controller.altRight.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.heightTopShort(controller.altSupRight.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.diamShort(controller.referenceCircleDiameterRight.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln()
      ..writeln("${context.l10n.leftEye}:")
      ..writeln(
        "${context.l10n.dnpShort(controller.dnpLeft.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.heightShort(controller.altLeft.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.heightTopShort(controller.altSupLeft.toStringAsFixed(1))} ${context.l10n.unitMm}",
      )
      ..writeln(
        "${context.l10n.diamShort(controller.referenceCircleDiameterLeft.toStringAsFixed(1))} ${context.l10n.unitMm}",
      );

    return buffer.toString().trim();
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _getResultsText(context)));
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _shareResults(BuildContext context) async {
    try {
      final bytes = await screenshotController.capture();

      if (bytes != null) {
        await SharePlus.instance.share(
          ShareParams(
            text: _getResultsText(context),
            subject: context.l10n.measurementsShareSubject,
            files: [
              XFile.fromData(
                bytes,
                name: 'measurements.png',
                mimeType: 'image/png',
              ),
            ],
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: _getResultsText(context),
            subject: context.l10n.measurementsShareSubject,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing: $e');

      await SharePlus.instance.share(
        ShareParams(
          text: _getResultsText(context),
          subject: context.l10n.measurementsShareSubject,
        ),
      );
    }

    if (context.mounted) Navigator.pop(context);
  }
}
