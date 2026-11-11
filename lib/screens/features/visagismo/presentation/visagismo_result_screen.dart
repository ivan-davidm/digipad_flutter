import 'dart:io';

import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final shortestSide = MediaQuery.sizeOf(context).shortestSide;
            final isLargeScreen = shortestSide >= 600;
            // On a big tablet/totem screen the suggestion cards get more
            // room; on phones they stay compact. Driven by screen size, not
            // a fixed pixel height, so the panel never overflows regardless
            // of device.
            final suggestionsHeight = isLargeScreen ? 220.0 : 176.0;
            final photoFlexBasis = isLargeScreen ? 0.42 : 0.5;

            // The whole panel is wrapped in a scroll view with a minimum
            // height equal to the available space: on a short viewport
            // (e.g. a tablet in landscape) it scrolls instead of
            // overflowing; on a tall one it still fills the screen edge to
            // edge like before.
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    if (imagePath != null && imagePath.isNotEmpty)
                      SizedBox(
                        height: constraints.maxHeight * photoFlexBasis,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(imagePath), fit: BoxFit.cover),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.55),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildResultCard(
                      context: context,
                      result: result,
                      imagePath: imagePath,
                      cubit: cubit,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.visibility_outlined,
                            color: Colors.white54,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Lentes sugeridos',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Tocá uno para elegir el color del marco',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: suggestionsHeight,
                      child: FrameSuggestionsList(catalog: catalogToShow),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResultCard({
    required BuildContext context,
    required FaceShapeResult? result,
    required String? imagePath,
    required VisagismoCubit cubit,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      transform: Matrix4.translationValues(0, -20, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: result != null
                    ? FaceShapeBadge(result: result)
                    : const Text(
                        'No se detectó un rostro en la foto.',
                        style: TextStyle(color: Colors.white70),
                      ),
              ),
              TextButton.icon(
                onPressed: () => cubit.retakePhoto(),
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Repetir'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ],
          ),
          if (result != null && result.recommendedFrameTags.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Recomendado para tu forma de rostro',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.recommendedFrameTags
                  .map((tag) => _RecommendationChip(label: tag))
                  .toList(),
            ),
          ],
          if (imagePath != null && imagePath.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  imagePath == _savedImagePath
                      ? Icons.check_circle
                      : Icons.hourglass_top,
                  color: imagePath == _savedImagePath
                      ? const Color(0xFF00E676)
                      : Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  imagePath == _savedImagePath
                      ? 'Guardada en la galería interna'
                      : 'Guardando en la galería…',
                  style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationChip extends StatelessWidget {
  const _RecommendationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.deepPurpleAccent.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
