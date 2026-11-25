import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_lens_detector.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/glasses_fit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Frames whose picture is bundled (an asset) can be tried on: the picture is
/// a front view with a transparent background and see-through lenses, and its
/// lens centres are found automatically. Network pictures (a future óptica
/// catalog) would need the same kind of picture and a network loader here.
bool canTryOn(FrameCatalogItem item) => item.thumbnailUrl.startsWith('assets/');

/// A frame picture ready to draw: the decoded image and its lens centres.
class _FramePicture {
  const _FramePicture(this.image, this.lenses);

  final ui.Image image;
  final FrameLensAnchors lenses;
}

/// The captured photo with [frame] drawn over the eyes (placed from
/// [anchor] and the frame's own lens centres, see `glasses_fit.dart`), shown
/// like `BoxFit.cover`.
///
/// Drag to move the glasses, pinch to resize, twist to rotate, double tap to
/// go back to the automatic placement. The adjustment lives in this state and
/// is kept when switching frames; it is reset for a new photo.
/// [GlassesTryOnViewState.renderPng] exports exactly what is on screen, at
/// the photo's full resolution.
class GlassesTryOnView extends StatefulWidget {
  const GlassesTryOnView({
    super.key,
    required this.photoPath,
    required this.anchor,
    required this.frame,
  });

  final String photoPath;
  final GlassesAnchor? anchor;
  final FrameCatalogItem? frame;

  @override
  State<GlassesTryOnView> createState() => GlassesTryOnViewState();
}

class GlassesTryOnViewState extends State<GlassesTryOnView> {
  // Frame pictures are small and reused across photos: decode and measure
  // each one once.
  static final Map<String, Future<_FramePicture>> _pictures = {};

  ui.Image? _photo;
  _FramePicture? _frame;
  GlassesAdjust _adjust = GlassesAdjust.none;

  // Gesture bookkeeping.
  GlassesAdjust _gestureStart = GlassesAdjust.none;
  Offset _focalStart = Offset.zero;
  double _coverScale = 1;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
    _loadFrame();
  }

  @override
  void didUpdateWidget(GlassesTryOnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) {
      _adjust = GlassesAdjust.none;
      _loadPhoto();
    }
    if (oldWidget.frame?.thumbnailUrl != widget.frame?.thumbnailUrl) {
      _loadFrame();
    }
  }

  @override
  void dispose() {
    _photo?.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final path = widget.photoPath;
    try {
      final image = await _decode(await File(path).readAsBytes());
      if (!mounted || path != widget.photoPath) {
        image.dispose();
        return;
      }
      setState(() {
        _photo?.dispose();
        _photo = image;
      });
    } catch (e) {
      debugPrint('[TryOn] could not load photo: $e');
    }
  }

  Future<void> _loadFrame() async {
    final frame = widget.frame;
    if (frame == null || !canTryOn(frame)) {
      if (_frame != null) setState(() => _frame = null);
      return;
    }
    final asset = frame.thumbnailUrl;
    try {
      final picture = await _pictures.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        final image = await _decode(data.buffer.asUint8List());
        final rgba = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final lenses =
            (rgba == null
                ? null
                : detectFrameLenses(
                    rgba.buffer.asUint8List(),
                    image.width,
                    image.height,
                  )) ??
            FrameLensAnchors.guess(image.width, image.height);
        if (!lenses.detected) {
          debugPrint('[TryOn] lenses not found in $asset, guessing');
        }
        return _FramePicture(image, lenses);
      });
      if (!mounted || widget.frame?.thumbnailUrl != asset) return;
      setState(() => _frame = picture);
    } catch (e) {
      _pictures.remove(asset);
      debugPrint('[TryOn] could not load frame $asset: $e');
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    // Same engine decoder as Image.file, so EXIF orientation is applied the
    // same way (the photo is upright, like the coordinates ML Kit reports).
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  void resetAdjust() => setState(() => _adjust = GlassesAdjust.none);

  GlassesPlacement? _placement() {
    final photo = _photo;
    final frame = _frame;
    if (photo == null || frame == null) return null;
    final w = photo.width.toDouble();
    final h = photo.height.toDouble();
    final frameWidth = frame.image.width.toDouble();
    final auto =
        placeGlasses(
          widget.anchor,
          frame.lenses,
          frameWidth: frameWidth,
          photoWidth: w,
          photoHeight: h,
        ) ??
        defaultGlassesPlacement(
          frame.lenses,
          frameWidth: frameWidth,
          photoWidth: w,
          photoHeight: h,
        );
    return _adjust.applyTo(auto);
  }

  /// The photo with the glasses, at the photo's own resolution, as PNG.
  /// Null while the photo or the frame are still loading.
  Future<Uint8List?> renderPng() async {
    final photo = _photo;
    final frame = _frame;
    final placement = _placement();
    if (photo == null || frame == null || placement == null) return null;
    final recorder = ui.PictureRecorder();
    paintGlassesTryOn(Canvas(recorder), photo, frame.image, placement);
    final picture = recorder.endRecording();
    final image = await picture.toImage(photo.width, photo.height);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    if (photo == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white54)),
      );
    }
    final hasGlasses = _frame != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        _coverScale = max(
          constraints.maxWidth / photo.width,
          constraints.maxHeight / photo.height,
        );
        return GestureDetector(
          onScaleStart: hasGlasses
              ? (d) {
                  _gestureStart = _adjust;
                  _focalStart = d.localFocalPoint;
                }
              : null,
          onScaleUpdate: hasGlasses
              ? (d) {
                  final moved = (d.localFocalPoint - _focalStart) / _coverScale;
                  setState(
                    () => _adjust = _gestureStart.copyWith(
                      dx: _gestureStart.dx + moved.dx,
                      dy: _gestureStart.dy + moved.dy,
                      scale: _gestureStart.scale * d.scale,
                      rotation: _gestureStart.rotation + d.rotation,
                    ),
                  );
                }
              : null,
          onDoubleTap: hasGlasses ? resetAdjust : null,
          child: CustomPaint(
            size: Size.infinite,
            painter: _TryOnPainter(
              photo: photo,
              frame: _frame?.image,
              placement: _placement(),
            ),
          ),
        );
      },
    );
  }
}

/// Paints [photo] at its own size from the origin and [frame] over it at
/// [placement] (photo pixels). Shared by the screen and the export, so the
/// saved image is exactly what the operator saw.
void paintGlassesTryOn(
  Canvas canvas,
  ui.Image photo,
  ui.Image? frame,
  GlassesPlacement? placement,
) {
  canvas.drawImage(
    photo,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.medium,
  );
  if (frame == null || placement == null) return;
  canvas
    ..save()
    ..translate(placement.centerX, placement.centerY)
    ..rotate(placement.rotation)
    ..scale(placement.scale)
    ..translate(-placement.anchorX, -placement.anchorY)
    ..drawImage(
      frame,
      Offset.zero,
      Paint()
        // The frame pictures are small: smooth upscaling matters.
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    )
    ..restore();
}

class _TryOnPainter extends CustomPainter {
  _TryOnPainter({
    required this.photo,
    required this.frame,
    required this.placement,
  });

  final ui.Image photo;
  final ui.Image? frame;
  final GlassesPlacement? placement;

  @override
  void paint(Canvas canvas, Size size) {
    // BoxFit.cover, centred.
    final scale = max(size.width / photo.width, size.height / photo.height);
    canvas
      ..clipRect(Offset.zero & size)
      ..translate(
        (size.width - photo.width * scale) / 2,
        (size.height - photo.height * scale) / 2,
      )
      ..scale(scale);
    paintGlassesTryOn(canvas, photo, frame, placement);
  }

  @override
  bool shouldRepaint(_TryOnPainter oldDelegate) => true;
}
