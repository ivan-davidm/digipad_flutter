import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:flutter/material.dart';

String faceShapeLabel(FaceShape shape) {
  switch (shape) {
    case FaceShape.redondo:
      return 'Redondo';
    case FaceShape.cuadrado:
      return 'Cuadrado';
    case FaceShape.ovalado:
      return 'Ovalado';
    case FaceShape.corazon:
      return 'Corazón';
    case FaceShape.diamante:
      return 'Diamante';
    case FaceShape.alargado:
      return 'Alargado';
  }
}

/// Small reusable chip showing the detected face shape, used on both the
/// live AR screen (as a live hint) and the result screen.
class FaceShapeBadge extends StatelessWidget {
  const FaceShapeBadge({super.key, required this.result});

  final FaceShapeResult result;

  @override
  Widget build(BuildContext context) {
    final confidencePct = (result.confidence * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.face_retouching_natural, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            '${faceShapeLabel(result.shape)} · $confidencePct%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
