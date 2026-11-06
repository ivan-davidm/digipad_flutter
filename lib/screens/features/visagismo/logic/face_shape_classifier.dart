/// Pure geometry-ratio classifier for "visagismo": given a handful of facial
/// measurements (derived natively from an ARCore face mesh), decides which of
/// the 6 classic face-shape categories the face belongs to and which frame
/// styles an optician would recommend for it.
///
/// Deliberately has zero Flutter/Firestore/platform-channel imports so it can
/// be unit-tested without any AR hardware.
///
/// Colorimetry (skin/hair undertone), brow-line alignment and pupillary
/// distance are NOT inputs here — the client explicitly scoped those as
/// additional factors a professional optician evaluates manually, not as
/// classifier inputs. They would surface as secondary advisory text next to
/// the shape result, not as fields on [FaceMeasurements].
library;

enum FaceShape { redondo, cuadrado, ovalado, corazon, diamante, alargado }

class FaceMeasurements {
  /// Bizygomatic width (cheekbone to cheekbone), in millimeters.
  final double faceWidthMm;

  /// Hairline/forehead-top to chin, in millimeters.
  final double faceHeightMm;

  final double jawWidthMm;
  final double foreheadWidthMm;

  /// Angularity proxy for the jaw: lower = sharper/more square, higher =
  /// softer/more rounded.
  final double jawAngleDeg;

  /// 0 = round/blunt chin .. 1 = pointed chin.
  final double chinSharpness;

  const FaceMeasurements({
    required this.faceWidthMm,
    required this.faceHeightMm,
    required this.jawWidthMm,
    required this.foreheadWidthMm,
    required this.jawAngleDeg,
    required this.chinSharpness,
  });
}

class FaceShapeResult {
  final FaceShape shape;

  /// Ranked, best-fit first.
  final List<String> recommendedFrameTags;
  final List<String> avoidFrameTags;

  /// 0..1, how decisively the ratios cleared the nearest threshold.
  final double confidence;

  const FaceShapeResult({
    required this.shape,
    required this.recommendedFrameTags,
    required this.avoidFrameTags,
    required this.confidence,
  });
}

// Tunable thresholds — calibrate against real reference faces once device
// measurements are available (see plan Phase 6 risk: thresholds are a first
// pass, not yet validated against the client's reference data).
const double _kElongatedWidthHeightRatioMax = 0.72;
const double _kBalancedWidthHeightRatioMin = 0.78;
const double _kBalancedWidthHeightRatioMax = 1.05;
const double _kRoundJawAngleMinDeg = 150.0;
const double _kRoundChinSharpnessMax = 0.35;
const double _kSquareJawAngleMaxDeg = 130.0;
const double _kSquareJawToCheekRatioMin = 0.90;
const double _kHeartForeheadToCheekRatioMin = 0.95;
const double _kHeartJawToCheekRatioMax = 0.80;
const double _kDiamondCheekDominanceMin = 1.08;

FaceShapeResult classifyFaceShape(FaceMeasurements m) {
  final widthHeightRatio = m.faceWidthMm / m.faceHeightMm;
  final jawToCheekRatio = m.jawWidthMm / m.faceWidthMm;
  final foreheadToCheekRatio = m.foreheadWidthMm / m.faceWidthMm;

  // 1. Alargado: clearly taller than wide, regardless of jaw/forehead ratios.
  if (widthHeightRatio <= _kElongatedWidthHeightRatioMax) {
    return FaceShapeResult(
      shape: FaceShape.alargado,
      recommendedFrameTags: const ['oversize', 'lente_alto'],
      avoidFrameTags: const ['chico', 'bajo'],
      confidence: _distanceConfidence(
        widthHeightRatio,
        _kElongatedWidthHeightRatioMax,
        0.5,
      ),
    );
  }

  final isBalancedRatio =
      widthHeightRatio >= _kBalancedWidthHeightRatioMin &&
      widthHeightRatio <= _kBalancedWidthHeightRatioMax;

  // 2. Redondo: width ~= height, soft/curved jaw, blunt chin.
  if (isBalancedRatio &&
      m.jawAngleDeg >= _kRoundJawAngleMinDeg &&
      m.chinSharpness <= _kRoundChinSharpnessMax) {
    return FaceShapeResult(
      shape: FaceShape.redondo,
      recommendedFrameTags: const ['cuadrado', 'rectangular', 'cat_eye'],
      avoidFrameTags: const ['redondo_chico'],
      confidence: _distanceConfidence(
        m.jawAngleDeg,
        _kRoundJawAngleMinDeg,
        30,
      ),
    );
  }

  // 3. Cuadrado/Rectangular: width ~= (or slightly >) height, angular jaw,
  //    jaw width close to cheekbone width.
  if (widthHeightRatio >= _kBalancedWidthHeightRatioMin &&
      m.jawAngleDeg <= _kSquareJawAngleMaxDeg &&
      jawToCheekRatio >= _kSquareJawToCheekRatioMin) {
    return FaceShapeResult(
      shape: FaceShape.cuadrado,
      recommendedFrameTags: const ['redondo', 'ovalado', 'curvo'],
      avoidFrameTags: const ['anguloso', 'chico'],
      confidence: _distanceConfidence(
        m.jawAngleDeg,
        _kSquareJawAngleMaxDeg,
        30,
      ),
    );
  }

  // 4. Corazón / Triángulo invertido: forehead/cheeks wide, jaw narrows
  //    sharply.
  if (foreheadToCheekRatio >= _kHeartForeheadToCheekRatioMin &&
      jawToCheekRatio <= _kHeartJawToCheekRatioMax) {
    return FaceShapeResult(
      shape: FaceShape.corazon,
      recommendedFrameTags: const [
        'redondo',
        'ovalado',
        'rimless',
        'ancho_abajo',
      ],
      avoidFrameTags: const ['browline_pesado'],
      confidence: _distanceConfidence(
        jawToCheekRatio,
        _kHeartJawToCheekRatioMax,
        0.3,
      ),
    );
  }

  // 5. Diamante: cheekbone width is the local maximum — wider than both
  //    forehead and jaw.
  final cheekDominanceOverForehead = foreheadToCheekRatio == 0
      ? 0
      : 1 / foreheadToCheekRatio;
  final cheekDominanceOverJaw = jawToCheekRatio == 0 ? 0 : 1 / jawToCheekRatio;
  if (cheekDominanceOverForehead >= _kDiamondCheekDominanceMin &&
      cheekDominanceOverJaw >= _kDiamondCheekDominanceMin) {
    final dominance = cheekDominanceOverForehead < cheekDominanceOverJaw
        ? cheekDominanceOverForehead
        : cheekDominanceOverJaw;
    return FaceShapeResult(
      shape: FaceShape.diamante,
      recommendedFrameTags: const ['ovalado', 'circular', 'cat_eye_suave'],
      avoidFrameTags: const ['estrecho', 'rectangular_rigido'],
      confidence: _distanceConfidence(
        dominance.toDouble(),
        _kDiamondCheekDominanceMin,
        0.3,
      ),
    );
  }

  // 6. Ovalado: default when no other branch fires decisively — ratios all
  //    within "balanced" bands.
  return const FaceShapeResult(
    shape: FaceShape.ovalado,
    recommendedFrameTags: ['casi_cualquier_forma_moderada'],
    avoidFrameTags: [],
    confidence: 0.5,
  );
}

/// Normalizes how far [value] cleared [threshold] relative to a [spread] that
/// represents "fully confident" separation, clamped to 0..1. Used so the UI
/// can show e.g. "forma: Ovalado (confianza moderada)" instead of false
/// precision.
double _distanceConfidence(double value, double threshold, double spread) {
  if (spread <= 0) return 0.5;
  final distance = (value - threshold).abs();
  return (0.5 + (distance / spread) * 0.5).clamp(0.5, 1.0);
}
