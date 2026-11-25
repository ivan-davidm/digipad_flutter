import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/visagismo_labels.dart';
import 'package:flutter/material.dart';

/// Hidden diagnostics for the optician: the raw numbers behind a face-shape
/// result (open it with a long press on the result card). Useful to tune the
/// classifier thresholds against real faces.
Future<void> showFaceAnalysisDebugSheet(
  BuildContext context,
  FaceAnalysis? analysis,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF121212),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FaceAnalysisDebugSheet(analysis: analysis),
  );
}

class _FaceAnalysisDebugSheet extends StatelessWidget {
  const _FaceAnalysisDebugSheet({required this.analysis});

  final FaceAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final m = a?.measurements;
    final shape = a?.shape;

    String f(double? v, {int digits = 2, String unit = ''}) =>
        v == null ? '—' : '${v.toStringAsFixed(digits)}$unit';

    final l10n = AppLocalizations.of(context);
    final rows = <(String, String)>[
      if (a?.issue != null) (l10n.visagismoDiagIssue, a!.issue!.name),
      if (a?.errorDetail != null) (l10n.visagismoDiagDetectorError, a!.errorDetail!),
      if (shape != null) (l10n.visagismoDiagShape, faceShapeName(l10n, shape.shape)),
      if (shape != null) (l10n.visagismoDiagConfidence, f(shape.confidence)),
      (l10n.visagismoDiagYaw, f(a?.yawDeg, digits: 1, unit: '°')),
      (l10n.visagismoDiagPitch, f(a?.pitchDeg, digits: 1, unit: '°')),
      (l10n.visagismoDiagRoll, f(a?.rollDeg, digits: 1, unit: '°')),
      if (m != null) ...[
        (l10n.visagismoDiagWidthHeight, f(m.faceWidthMm / m.faceHeightMm)),
        (l10n.visagismoDiagJawCheek, f(m.jawWidthMm / m.faceWidthMm)),
        (l10n.visagismoDiagForeheadCheek, f(m.foreheadWidthMm / m.faceWidthMm)),
        (l10n.visagismoDiagJawAngle, f(m.jawAngleDeg, digits: 1, unit: '°')),
        (l10n.visagismoDiagChin, f(m.chinSharpness)),
        (l10n.visagismoDiagWidthHeightPx,
            '${m.faceWidthMm.toStringAsFixed(0)} × ${m.faceHeightMm.toStringAsFixed(0)}'),
      ],
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.visagismoDiagTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (a == null)
              Text(
                l10n.visagismoDiagNoData,
                style: const TextStyle(color: Colors.white54),
              )
            else
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 10),
            Text(
              l10n.visagismoDiagFootnote,
              style: const TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
