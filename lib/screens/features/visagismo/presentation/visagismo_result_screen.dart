import 'dart:io';

import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/face_shape_badge.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/frame_suggestions_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows the captured photo, the classified face shape, and a horizontal
/// row of suggested reference frames for that shape.
///
/// This app (`digipad`, "DigiTower 3D Premium") already runs AS the Tótem —
/// it's the big-screen kiosk itself (see `TotemCubit`/the "TÓTEM activa"
/// badge on `home_screen.dart`), so there is nothing to "send to a Tótem"
/// from here; that round-trip only makes sense from the separate
/// `digipad_totem` DigiPad companion app. Every capture is saved straight to
/// this app's own internal gallery (`GalleryStorage`, the same store every
/// other capture flow in this app uses) so it shows up locally right away.
class VisagismoResultScreen extends StatefulWidget {
  const VisagismoResultScreen({super.key});

  @override
  State<VisagismoResultScreen> createState() => _VisagismoResultScreenState();
}

class _VisagismoResultScreenState extends State<VisagismoResultScreen> {
  String? _savedImagePath;

  Future<void> _maybeSaveCapture(BuildContext context) async {
    final imagePath = context.read<VisagismoCubit>().state.capturedImagePath;
    if (imagePath == null || imagePath.isEmpty || imagePath == _savedImagePath) {
      return;
    }
    _savedImagePath = imagePath;
    await GalleryStorage().saveImage(File(imagePath));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VisagismoCubit, VisagismoState>(
      listenWhen: (p, c) => p.capturedImagePath != c.capturedImagePath,
      listener: (context, state) => _maybeSaveCapture(context),
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeSaveCapture(context);
          });
          return _buildBody(context);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<VisagismoCubit, VisagismoState>(
      builder: (context, state) {
        final result = state.lastClassification;
        final imagePath = state.capturedImagePath;
        final cubit = context.read<VisagismoCubit>();

        final filteredCatalog = result == null
            ? state.catalog
            : state.catalog
                .where(
                  (item) => item.shapeTags
                      .any((tag) => result.recommendedFrameTags.contains(tag)),
                )
                .toList();
        final catalogToShow =
            filteredCatalog.isEmpty ? state.catalog : filteredCatalog;

        return Column(
          children: [
            if (imagePath != null && imagePath.isNotEmpty)
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.file(File(imagePath), fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (result != null)
                    FaceShapeBadge(result: result)
                  else
                    const Text(
                      'No se detectó un rostro en la foto.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  TextButton.icon(
                    onPressed: () => cubit.retakePhoto(),
                    icon: const Icon(Icons.replay),
                    label: const Text('Repetir'),
                  ),
                ],
              ),
            ),
            if (result != null && result.recommendedFrameTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Recomendado para esta forma de rostro: '
                  '${result.recommendedFrameTags.join(', ')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            if (imagePath != null && imagePath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      imagePath == _savedImagePath
                          ? Icons.check_circle
                          : Icons.hourglass_top,
                      color: imagePath == _savedImagePath
                          ? const Color(0xFF00E676)
                          : Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      imagePath == _savedImagePath
                          ? 'Guardada en la galería interna'
                          : 'Guardando en la galería…',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: FrameSuggestionsList(catalog: catalogToShow),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
