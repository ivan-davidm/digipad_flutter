import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
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

    final rows = <(String, String)>[
      if (a?.issue != null) ('Problema', a!.issue!.name),
      if (shape != null) ('Forma', shape.shape.name),
      if (shape != null) ('Confianza', f(shape.confidence)),
      ('Giro de cabeza (yaw)', f(a?.yawDeg, digits: 1, unit: '°')),
      ('Cabeceo (pitch)', f(a?.pitchDeg, digits: 1, unit: '°')),
      ('Inclinación (roll)', f(a?.rollDeg, digits: 1, unit: '°')),
      if (m != null) ...[
        ('Ancho / alto', f(m.faceWidthMm / m.faceHeightMm)),
        ('Mandíbula / pómulos', f(m.jawWidthMm / m.faceWidthMm)),
        ('Frente / pómulos', f(m.foreheadWidthMm / m.faceWidthMm)),
        ('Ángulo de mandíbula', f(m.jawAngleDeg, digits: 1, unit: '°')),
        ('Mentón (0 romo – 1 puntiagudo)', f(m.chinSharpness)),
        ('Ancho / alto (px)',
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
            const Text(
              'Mediciones (diagnóstico)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (a == null)
              const Text(
                'Sin datos de la última foto.',
                style: TextStyle(color: Colors.white54),
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
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 10),
            const Text(
              'Las proporciones se calculan en píxeles sobre el contorno de '
              'ML Kit, que llega a media frente (no a la línea del pelo). '
              'Los umbrales del clasificador aún no están validados contra '
              'rostros de referencia.',
              style: TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
