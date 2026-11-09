import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DetectionType {
  refTL,
  refTR,
  refBL,
  refBR,
  pupilRight,
  pupilLeft,
  lensRightTop,
  lensRightBottom,
  lensLeftTop,
  lensLeftBottom,
}

enum MeasurementMode { conAccesorio, sinAccesorio }

class DetectionPoint {
  String id;
  DetectionType type;
  Offset position;
  String label;

  DetectionPoint({
    required this.id,
    required this.type,
    required this.position,
    required this.label,
  });
}

class OpticalController extends ChangeNotifier {
  List<DetectionPoint> points = [];

  double ajusteHorizontal = 1.0;
  double ajusteVertical = 1.0;
  double referenceCircleDiameterRight = 40.0;
  double referenceCircleDiameterLeft = 40.0;
  bool _initialDiameterSynced = false;

  bool showCircles = true;
  bool showChips = false;
  bool isBifocal = false;
  double bifocalLineOffset = 0.0;

  double milimetrosPorPixel = 0;
  double pixelFactorX = 0;
  double pixelFactorY = 0;
  double di = 0;
  double puente = 0;
  double dnpRight = 0;
  double dnpLeft = 0;
  double altRight = 0;
  double altLeft = 0;
  double aroAlt = 0;
  double aroAnc = 0;
  double diametroRight = 0;
  double diametroLeft = 0;
  double calcRadiusPxRight = 0;
  double calcRadiusPxLeft = 0;
  double altSupRight = 0;
  double altSupLeft = 0;
  double anchoExtArmazon = 0;

  MeasurementMode mode = MeasurementMode.conAccesorio;
  double? frameWidthMm;

  double? pantoscopicAngle;

  DetectionPoint? selectedPoint;

  OpticalController() {
    _loadCalibration();
  }

  Future<void> _loadCalibration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      ajusteHorizontal =
          prefs.getDouble('ajusteHorizontal')?.clamp(0.9, 1.25) ?? 1.0;
      ajusteVertical =
          prefs.getDouble('ajusteVertical')?.clamp(0.9, 1.25) ?? 1.0;

      // Si la imagen ya terminó de cargar sus puntos, actualizamos las fórmulas
      if (points.isNotEmpty) {
        calculateFormulas();
      } else {
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error cargando la calibración: $e");
    }
  }

  // Guarda los valores de calibración en memoria persistente
  Future<void> _saveCalibration(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (key == 'ajusteHorizontal') {
        ajusteHorizontal = value.clamp(0.9, 1.25);
      } else if (key == 'ajusteVertical') {
        ajusteVertical = value.clamp(0.9, 1.25);
      }

      await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint("Error guardando la calibración: $e");
    }
  }

  void initialize(
    Map<String, dynamic> detections,
    Size imageSize, {
    MeasurementMode mode = MeasurementMode.conAccesorio,
  }) {
    points.clear();
    this.mode = mode;

    Offset toPixel(dynamic item) {
      double nx = (item['x'] as num).toDouble();
      double ny = (item['y'] as num).toDouble();
      return Offset(nx * imageSize.width, ny * imageSize.height);
    }

    if (mode == MeasurementMode.sinAccesorio) {
      // No circles/ref-bar needed. Detect eyes and seed L-markers from image size.
      List<dynamic> rawEyes = detections['eyes'] ?? [];
      bool eyesAdded = false;
      if (rawEyes.length >= 2) {
        List<Offset> eyes = rawEyes.map((e) => toPixel(e)).toList()
          ..sort((a, b) => a.dx.compareTo(b.dx));
        final double minDim = math.min(imageSize.width, imageSize.height);
        final bool valid = eyes.every((e) =>
            e.dx > minDim * 0.05 &&
            e.dy > minDim * 0.05 &&
            e.dx < imageSize.width - minDim * 0.05 &&
            e.dy < imageSize.height - minDim * 0.05);
        if (valid) {
          _addPoint(eyes[0], DetectionType.pupilRight, "P_1");
          _addPoint(eyes[1], DetectionType.pupilLeft, "P_2");
          eyesAdded = true;
        }
      }
      if (!eyesAdded) {
        _addPoint(Offset(imageSize.width / 3.0, imageSize.height / 2.0),
            DetectionType.pupilRight, "P_1");
        _addPoint(Offset(imageSize.width * 2.0 / 3.0, imageSize.height / 2.0),
            DetectionType.pupilLeft, "P_2");
      }
      // Seed L-markers around each pupil.
      final Offset p1 = getPoint(DetectionType.pupilRight);
      final Offset p2 = getPoint(DetectionType.pupilLeft);
      final double xOff = imageSize.width * 0.15;
      final double yOff = imageSize.height * 0.10;
      _addPoint(
        Offset((p1.dx - xOff).clamp(0, imageSize.width),
            (p1.dy - yOff).clamp(0, imageSize.height)),
        DetectionType.lensRightTop, "R_TL");
      _addPoint(
        Offset((p1.dx + xOff).clamp(0, imageSize.width),
            (p1.dy + yOff).clamp(0, imageSize.height)),
        DetectionType.lensRightBottom, "R_BR");
      _addPoint(
        Offset((p2.dx - xOff).clamp(0, imageSize.width),
            (p2.dy - yOff).clamp(0, imageSize.height)),
        DetectionType.lensLeftTop, "L_TL");
      _addPoint(
        Offset((p2.dx + xOff).clamp(0, imageSize.width),
            (p2.dy + yOff).clamp(0, imageSize.height)),
        DetectionType.lensLeftBottom, "L_BR");
      _initialDiameterSynced = false;
      calculateFormulas();
      return;
    }

    List<dynamic> rawCircles = detections['circles'] ?? [];
    List<Offset> circleOffsets = rawCircles.map((c) => toPixel(c)).toList();

    // Reject circles stuck at image corners — TFLite returns (0,0) or (1,1)
    // normalised when it fails to detect. Same 5% border margin used for eyes.
    final double minDim = math.min(imageSize.width, imageSize.height);
    circleOffsets = circleOffsets.where((e) =>
        e.dx > minDim * 0.05 &&
        e.dy > minDim * 0.05 &&
        e.dx < imageSize.width - minDim * 0.05 &&
        e.dy < imageSize.height - minDim * 0.05).toList();

    if (circleOffsets.isNotEmpty) {
      if (circleOffsets.length >= 4) {
        final pts = circleOffsets.take(4).toList();

        double cx = 0, cy = 0;
        for (var p in pts) {
          cx += p.dx;
          cy += p.dy;
        }
        cx /= 4;
        cy /= 4;

        pts.sort((a, b) {
          double angleA = math.atan2(a.dy - cy, a.dx - cx);
          double angleB = math.atan2(b.dy - cy, b.dx - cx);
          return angleA.compareTo(angleB);
        });

        double len1 = (pts[0] - pts[1]).distance + (pts[2] - pts[3]).distance;
        double len2 = (pts[1] - pts[2]).distance + (pts[3] - pts[0]).distance;

        List<Offset> pair1, pair2;
        if (len1 > len2) {
          pair1 = [pts[0], pts[1]];
          pair2 = [pts[2], pts[3]];
        } else {
          pair1 = [pts[1], pts[2]];
          pair2 = [pts[3], pts[0]];
        }

        pair1.sort((a, b) => a.dx.compareTo(b.dx));
        pair2.sort((a, b) => a.dx.compareTo(b.dx));

        final avgY1 = (pair1[0].dy + pair1[1].dy) / 2;
        final avgY2 = (pair2[0].dy + pair2[1].dy) / 2;
        final List<Offset> topRow = avgY1 <= avgY2 ? pair1 : pair2;
        final List<Offset> bottomRow = avgY1 <= avgY2 ? pair2 : pair1;

        _addPoint(topRow[0], DetectionType.refTL, "A1");
        _addPoint(topRow[1], DetectionType.refTR, "A2");
        _addPoint(bottomRow[0], DetectionType.refBL, "B1");
        _addPoint(bottomRow[1], DetectionType.refBR, "B2");
      } else if (circleOffsets.length >= 2) {
        final List<Offset> sorted = circleOffsets
          ..sort((a, b) => a.dx.compareTo(b.dx));
        _addPoint(sorted.first, DetectionType.refTL, "A1");
        _addPoint(sorted.last, DetectionType.refTR, "A2");
      } else if (circleOffsets.length == 1) {
        _addPoint(circleOffsets.first, DetectionType.refTL, "A1");
      }
    }
    _ensureCalibrationPointsExist(imageSize);

    // Initialize lens corners first so the pupil fallback can use their centers.
    _initializeLensCorners(imageSize);

    List<dynamic> rawEyes = detections['eyes'] ?? [];
    bool eyesAdded = false;
    if (rawEyes.length >= 2) {
      List<Offset> eyes = rawEyes.map((e) => toPixel(e)).toList()
        ..sort((a, b) => a.dx.compareTo(b.dx));

      // Reject positions that are stuck at (≈0,≈0) — TFLite undetected default
      final minDim2 = math.min(imageSize.width, imageSize.height);
      final bool valid = eyes.every((e) =>
          e.dx > minDim2 * 0.05 &&
          e.dy > minDim2 * 0.05 &&
          e.dx < imageSize.width - minDim2 * 0.05 &&
          e.dy < imageSize.height - minDim2 * 0.05);

      if (valid) {
        _addPoint(eyes[0], DetectionType.pupilRight, "P_1");
        _addPoint(eyes[1], DetectionType.pupilLeft, "P_2");
        eyesAdded = true;
      }
    }

    if (!eyesAdded) {
      // Place fallback pupils at the center of each lens rectangle.
      final rTL = getPoint(DetectionType.lensRightTop);
      final rBR = getPoint(DetectionType.lensRightBottom);
      final lTL = getPoint(DetectionType.lensLeftTop);
      final lBR = getPoint(DetectionType.lensLeftBottom);
      _addPoint(
        Offset((rTL.dx + rBR.dx) / 2, (rTL.dy + rBR.dy) / 2),
        DetectionType.pupilRight,
        "P_1",
      );
      _addPoint(
        Offset((lTL.dx + lBR.dx) / 2, (lTL.dy + lBR.dy) / 2),
        DetectionType.pupilLeft,
        "P_2",
      );
    }

    _initialDiameterSynced = false;
    calculateFormulas();
  }

  void _addPoint(Offset pos, DetectionType type, String label) {
    if (!points.any((p) => p.type == type)) {
      points.add(
        DetectionPoint(
          id: type.toString(),
          type: type,
          position: pos,
          label: label,
        ),
      );
    }
  }

  void _ensureCalibrationPointsExist(Size size) {
    if (!points.any((p) => p.type == DetectionType.refTL)) {
      _addPoint(
        Offset(size.width * 0.2, size.height * 0.34),
        DetectionType.refTL,
        "A1",
      );
    }
    if (!points.any((p) => p.type == DetectionType.refTR)) {
      _addPoint(
        Offset(size.width * 0.8, size.height * 0.34),
        DetectionType.refTR,
        "A2",
      );
    }
    if (!points.any((p) => p.type == DetectionType.refBL)) {
      _addPoint(
        Offset(size.width * 0.2, size.height * 0.42),
        DetectionType.refBL,
        "B1",
      );
    }
    if (!points.any((p) => p.type == DetectionType.refBR)) {
      _addPoint(
        Offset(size.width * 0.8, size.height * 0.42),
        DetectionType.refBR,
        "B2",
      );
    }
  }

  void _initializeLensCorners(Size size) {
    final Offset a1 = getPoint(DetectionType.refTL);
    final Offset a2 = getPoint(DetectionType.refTR);
    final Offset b1 = getPoint(DetectionType.refBL);
    final Offset b2 = getPoint(DetectionType.refBR);

    final double barPx = (b2 - b1).distance;
    final double pxPerMm = barPx > 1 ? (130.0 / barPx) : (130.0 / (size.width * 0.6));
    final double bridgeHalf = 4.0 / pxPerMm;

    final double topMidX = (a1.dx + a2.dx) / 2.0;
    final double botMidX = (b1.dx + b2.dx) / 2.0;

    final double barH = ((b1.dy - a1.dy) + (b2.dy - a2.dy)) / 2.0;

    // Horizontal inset: 5% of total frame span
    final double frameSpanX = (b2.dx - a1.dx).abs();
    final double insetX = frameSpanX * 0.05;

    // Top Ls: always below BOTH B crosses — use the lower one as anchor.
    final double bMaxY = math.max(b1.dy, b2.dy);
    final double rTopY = bMaxY + math.max(40.0, barH * 0.20);
    final double lTopY = bMaxY + math.max(40.0, barH * 0.20);

    // Lens width in pixels (span between outer edge and bridge, per lens).
    final double rLensW = (botMidX - bridgeHalf) - (a1.dx + insetX);
    final double lLensW = (b2.dx - insetX) - (topMidX + bridgeHalf);

    // Lens height ≈ 65% of lens width (typical rectangular frame aspect ratio).
    // Bottom Ls drop by that height from the top Ls.
    final double rBotY = rTopY + rLensW * 0.65;
    final double lBotY = lTopY + lLensW * 0.65;

    _addPoint(Offset(a1.dx + insetX, rTopY), DetectionType.lensRightTop, "R_TL");
    _addPoint(Offset(botMidX - bridgeHalf, rBotY), DetectionType.lensRightBottom, "R_BR");
    _addPoint(Offset(topMidX + bridgeHalf, lTopY), DetectionType.lensLeftTop, "L_TL");
    _addPoint(Offset(b2.dx - insetX, lBotY), DetectionType.lensLeftBottom, "L_BR");
  }

  void handleTap(
    Offset localPosition,
    double scale,
    Offset translation, {
    double rotation = 0.0,
  }) {
    final imgPos = (localPosition - translation) / scale;
    final double hitRadius = 25 / scale;
    final double armLen = 40.0 / scale;
    final double lineTol = 10.0 / scale;

    try {
      final candidates = points.where((p) {
        final bool isCorner = p.type.index >= DetectionType.lensRightTop.index;
        if (isCorner) {
          // L corners: only match when the tap lands on an arm, not the center.
          return _isOnLArm(imgPos, p.position, p.type, armLen, lineTol, rotation);
        }
        return (p.position - imgPos).distance <= hitRadius;
      }).toList();

      if (candidates.isEmpty) {
        if (selectedPoint != null) {
          selectedPoint = null;
          notifyListeners();
        }
        return;
      }

      candidates.sort((a, b) {
        final distA = (a.position - imgPos).distance;
        final distB = (b.position - imgPos).distance;
        return distA.compareTo(distB);
      });

      selectedPoint = candidates.first;
      notifyListeners();
    } catch (_) {
      if (selectedPoint != null) {
        selectedPoint = null;
        notifyListeners();
      }
    }
  }

  /// Returns true when [tap] (image coords) falls within [tol] of either arm
  /// of the L-shape drawn at [corner]. The painter counter-rotates by
  /// -[rotation], so arm directions in image space use R(-rotation).
  bool _isOnLArm(
    Offset tap,
    Offset corner,
    DetectionType type,
    double armLen,
    double tol,
    double rotation,
  ) {
    // R(-rotation) * (x,y) = (x·cos(r) + y·sin(r), −x·sin(r) + y·cos(r))
    final double cr = math.cos(rotation);
    final double sr = math.sin(rotation);
    Offset toImg(double x, double y) =>
        Offset(x * cr + y * sr, -x * sr + y * cr);

    final List<Offset> armEnds;
    if (type == DetectionType.lensRightTop ||
        type == DetectionType.lensLeftTop) {
      // ┌ shape: right arm and down arm
      armEnds = [
        corner + toImg(armLen, 0),
        corner + toImg(0, armLen),
      ];
    } else {
      // ┘ shape: left arm and up arm
      armEnds = [
        corner + toImg(-armLen, 0),
        corner + toImg(0, -armLen),
      ];
    }

    for (final end in armEnds) {
      if (_distToSegment(tap, corner, end) <= tol) return true;
    }
    return false;
  }

  double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final ap = p - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq < 1e-10) return (p - a).distance;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final closest = a + Offset(ab.dx * t, ab.dy * t);
    return (p - closest).distance;
  }

  void handleDrag(Offset delta, double scale) {
    if (selectedPoint != null) {
      final actualDelta = delta / scale;
      selectedPoint!.position += actualDelta;
      _mirrorToLeftLensIfNeeded(selectedPoint!.type, actualDelta.dx);
      calculateFormulas();
      notifyListeners();
    }
  }

  void nudgeSelectedPoint(double dx, double dy) {
    if (selectedPoint != null) {
      selectedPoint!.position += Offset(dx, dy);
      _mirrorToLeftLensIfNeeded(selectedPoint!.type, dx);
      calculateFormulas();
      notifyListeners();
    }
  }

  /// Dragging a right-lens corner replicates the horizontal movement
  /// (mirrored) onto the matching left-lens corner, since the two frames
  /// are symmetric across the bridge, and snaps that mirrored corner to the
  /// same height as the dragged one. Left-lens corners stay independent and
  /// never move the right side.
  void _mirrorToLeftLensIfNeeded(DetectionType type, double dx) {
    DetectionType? mirrorType;
    if (type == DetectionType.lensRightTop) {
      mirrorType = DetectionType.lensLeftTop;
    } else if (type == DetectionType.lensRightBottom) {
      mirrorType = DetectionType.lensLeftBottom;
    }
    if (mirrorType == null) return;

    final draggedY = selectedPoint!.position.dy;
    for (final p in points) {
      if (p.type == mirrorType) {
        p.position = Offset(p.position.dx - dx, draggedY);
        break;
      }
    }
  }

  void setReferenceDiameterRight(double val) {
    referenceCircleDiameterRight = val;
    notifyListeners();
  }

  void setReferenceDiameterLeft(double val) {
    referenceCircleDiameterLeft = val;
    notifyListeners();
  }

  void setAjusteHorizontal(double val) {
    ajusteHorizontal = val.clamp(0.9, 1.25);
    calculateFormulas();
    _saveCalibration('ajusteHorizontal', ajusteHorizontal);
  }

  void setAjusteVertical(double val) {
    ajusteVertical = val.clamp(0.9, 1.25);
    calculateFormulas();
    _saveCalibration('ajusteVertical', ajusteVertical);
  }

  void deselect() {
    selectedPoint = null;
    notifyListeners();
  }

  void setFrameWidthMm(double? v) {
    frameWidthMm = v;
    calculateFormulas();
    notifyListeners();
  }

  void setPantoscopicAngle(double val) {
    pantoscopicAngle = val;
    notifyListeners();
  }

  void toggleCircles(bool val) {
    showCircles = val;
    notifyListeners();
  }

  void toggleChips(bool val) {
    showChips = val;
    notifyListeners();
  }

  void toggleBifocal(bool val) {
    isBifocal = val;
    notifyListeners();
  }

  void adjustBifocalLine(double delta) {
    bifocalLineOffset += delta;
    notifyListeners();
  }

  Offset getPoint(DetectionType type) {
    try {
      return points.firstWhere((p) => p.type == type).position;
    } catch (_) {
      return Offset.zero;
    }
  }

  Map<String, dynamic> toStateJson() {
    return {
      'points': points
          .map((p) => {
                'id': p.id,
                'type': p.type.name,
                'dx': p.position.dx,
                'dy': p.position.dy,
                'label': p.label,
              })
          .toList(),
      'results': {
        'di': di,
        'puente': puente,
        'dnpRight': dnpRight,
        'dnpLeft': dnpLeft,
        'altRight': altRight,
        'altLeft': altLeft,
        'altSupRight': altSupRight,
        'altSupLeft': altSupLeft,
        'aroAnc': aroAnc,
        'aroAlt': aroAlt,
        'anchoExtArmazon': anchoExtArmazon,
        'pixelFactorX': pixelFactorX,
        'pixelFactorY': pixelFactorY,
        'diametroRight': diametroRight,
        'diametroLeft': diametroLeft,
      },
      'pantoscopicAngle': pantoscopicAngle,
      'referenceCircleDiameterRight': referenceCircleDiameterRight,
      'referenceCircleDiameterLeft': referenceCircleDiameterLeft,
      'isBifocal': isBifocal,
      'bifocalLineOffset': bifocalLineOffset,
      'ajusteHorizontal': ajusteHorizontal,
      'ajusteVertical': ajusteVertical,
      'mode': mode.name,
      'frameWidthMm': frameWidthMm,
    };
  }

  void restoreFromStateJson(Map<String, dynamic> json) {
    ajusteHorizontal = (json['ajusteHorizontal'] as num?)?.toDouble() ?? 1.0;
    ajusteVertical = (json['ajusteVertical'] as num?)?.toDouble() ?? 1.0;
    pantoscopicAngle = (json['pantoscopicAngle'] as num?)?.toDouble();
    referenceCircleDiameterRight =
        (json['referenceCircleDiameterRight'] as num?)?.toDouble() ?? 40.0;
    referenceCircleDiameterLeft =
        (json['referenceCircleDiameterLeft'] as num?)?.toDouble() ?? 40.0;
    isBifocal = json['isBifocal'] as bool? ?? false;
    bifocalLineOffset = (json['bifocalLineOffset'] as num?)?.toDouble() ?? 0.0;
    mode = MeasurementMode.values.firstWhere(
      (e) => e.name == (json['mode'] as String? ?? 'conAccesorio'),
      orElse: () => MeasurementMode.conAccesorio,
    );
    frameWidthMm = (json['frameWidthMm'] as num?)?.toDouble();

    points.clear();
    selectedPoint = null;

    final pointsList = json['points'] as List<dynamic>? ?? [];
    for (final entry in pointsList) {
      final map = <String, dynamic>{};
      try {
        (entry as Map).forEach((k, v) => map[k.toString()] = v);
      } catch (_) {
        continue;
      }
      final typeStr = map['type'] as String;
      final type = DetectionType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => DetectionType.refTL,
      );
      points.add(DetectionPoint(
        id: map['id'] as String,
        type: type,
        position: Offset(
          (map['dx'] as num).toDouble(),
          (map['dy'] as num).toDouble(),
        ),
        label: map['label'] as String,
      ));
    }

    _initialDiameterSynced = true;
    calculateFormulas();
  }

  void calculateFormulas() {
    final Offset P_1 = getPoint(DetectionType.pupilRight);
    final Offset P_2 = getPoint(DetectionType.pupilLeft);
    final Offset rTL = getPoint(DetectionType.lensRightTop);
    final Offset rBR = getPoint(DetectionType.lensRightBottom);
    final Offset lTL = getPoint(DetectionType.lensLeftTop);
    final Offset lBR = getPoint(DetectionType.lensLeftBottom);

    late double Function(Offset) h;
    late double Function(Offset) v;

    if (mode == MeasurementMode.sinAccesorio) {
      // Scale derived from user-provided frame width (outer span of L-markers).
      final double outerSpanPx = (lBR.dx - rTL.dx).abs();
      milimetrosPorPixel = (frameWidthMm != null && frameWidthMm! > 0 && outerSpanPx > 1)
          ? frameWidthMm! / outerSpanPx
          : 1.0;
      h = (Offset p) => p.dx;
      v = (Offset p) => p.dy;
    } else {
      final Offset A1 = getPoint(DetectionType.refTL);
      final Offset A2 = getPoint(DetectionType.refTR);
      final Offset B1 = getPoint(DetectionType.refBL);
      final Offset B2 = getPoint(DetectionType.refBR);

      Offset barVec = B2 - B1;
      if (barVec.dx < 0) barVec = Offset(-barVec.dx, -barVec.dy);
      final double barLen = barVec.distance;
      final Offset hUnit = barLen > 1
          ? Offset(barVec.dx / barLen, barVec.dy / barLen)
          : const Offset(1, 0);
      Offset vUnit = Offset(-hUnit.dy, hUnit.dx);
      if (vUnit.dy < 0) vUnit = Offset(hUnit.dy, -hUnit.dx);

      milimetrosPorPixel = barLen > 1 ? (130.0 / barLen) : 1.0;

      final Offset midTop = Offset((A1.dx + A2.dx) / 2, (A1.dy + A2.dy) / 2);

      h = (Offset p) {
        final d = p - B1;
        return d.dx * hUnit.dx + d.dy * hUnit.dy;
      };
      v = (Offset p) {
        final d = p - midTop;
        return d.dx * vUnit.dx + d.dy * vUnit.dy;
      };
    }

    pixelFactorX = milimetrosPorPixel * ajusteHorizontal;
    pixelFactorY = milimetrosPorPixel * ajusteVertical;

    final double hP1 = h(P_1);
    final double hP2 = h(P_2);
    final double RE_1 = h(rTL);
    final double RC_1 = h(rBR);
    final double RC_2 = h(lTL);
    final double RE_2 = h(lBR);

    final double vP1 = v(P_1);
    final double vP2 = v(P_2);
    final double RS_1 = v(rTL);
    final double RI_1 = v(rBR);
    final double RS_2 = v(lTL);
    final double RI_2 = v(lBR);

    di = (hP2 - hP1).abs() * pixelFactorX;

    // Frame dimensions use milimetrosPorPixel (not ajuste) — physical, not calibrated.
    puente = (RC_2 - RC_1).abs() * milimetrosPorPixel;
    aroAnc = (((RC_1 - RE_1).abs() + (RE_2 - RC_2).abs()) / 2.0) * milimetrosPorPixel;
    aroAlt = (((RI_1 - RS_1).abs() + (RI_2 - RS_2).abs()) / 2.0) * milimetrosPorPixel;

    final double centroPx = (RC_1 + RC_2) / 2.0;
    dnpRight = (centroPx - hP1).abs() * pixelFactorX;
    dnpLeft = (hP2 - centroPx).abs() * pixelFactorX;

    final double radPxR = (hP1 - RE_1).abs();
    diametroRight = (radPxR * 2.0 * milimetrosPorPixel) + 1.0;
    calcRadiusPxRight = radPxR;

    final double radPxL = (RE_2 - hP2).abs();
    diametroLeft = (radPxL * 2.0 * milimetrosPorPixel) + 1.0;
    calcRadiusPxLeft = radPxL;

    altRight = (RI_1 - vP1).abs() * pixelFactorY;
    altLeft = (RI_2 - vP2).abs() * pixelFactorY;
    altSupRight = (vP1 - RS_1).abs() * pixelFactorY;
    altSupLeft = (vP2 - RS_2).abs() * pixelFactorY;

    if (mode == MeasurementMode.sinAccesorio) {
      anchoExtArmazon = frameWidthMm ?? 0;
    } else {
      // Ancho del armazón = aro derecho + puente + aro izquierdo ("incluyendo la
      // nariz"), sin calibración. Se calcula como suma, no de punta a punta.
      final double aroDerPx = (RC_1 - RE_1).abs();
      final double aroIzqPx = (RE_2 - RC_2).abs();
      final double puentePx = (RC_2 - RC_1).abs();
      anchoExtArmazon = (aroDerPx + puentePx + aroIzqPx) * milimetrosPorPixel;
    }

    if (!_initialDiameterSynced && diametroRight > 0) {
      // Auto-radius: average Euclidean distance from pupil to both L-corner vertices (mm)
      final dr1 = _euclidMm(P_1, rTL);
      final dr2 = _euclidMm(P_1, rBR);
      final dl1 = _euclidMm(P_2, lTL);
      final dl2 = _euclidMm(P_2, lBR);
      referenceCircleDiameterRight = (dr1 + dr2).clamp(40.0, 80.0);
      referenceCircleDiameterLeft = (dl1 + dl2).clamp(40.0, 80.0);
      _initialDiameterSynced = true;
    }

    notifyListeners();
  }

  double _euclidMm(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * pixelFactorX;
    final dy = (a.dy - b.dy) * pixelFactorY;
    return math.sqrt(dx * dx + dy * dy);
  }

}
