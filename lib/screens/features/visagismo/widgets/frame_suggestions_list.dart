import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontal, side-scrollable row of reference frame photos for the
/// classified face shape — replaces the old 3D-model grid (`FramePickerGrid`,
/// deleted) now that there's no live AR surface to render a selected model
/// onto. Nothing is "selected" here; it's purely a visual suggestion to show
/// the client, same spirit as flipping through a lookbook.
class FrameSuggestionsList extends StatelessWidget {
  const FrameSuggestionsList({super.key, required this.catalog});

  final List<FrameCatalogItem> catalog;

  @override
  Widget build(BuildContext context) {
    if (catalog.isEmpty) {
      return const Center(
        child: Text(
          'No hay marcos sugeridos disponibles todavía.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    final cubit = context.read<VisagismoCubit>();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: catalog.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        final item = catalog[index];
        return FutureBuilder<bool>(
          future: cubit.isFrameUnlocked(item),
          builder: (context, snapshot) {
            final unlocked = snapshot.data ?? item.isGeneric;
            return _FrameCard(item: item, isLocked: !unlocked);
          },
        );
      },
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({required this.item, required this.isLocked});

  final FrameCatalogItem item;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FrameImage(path: item.thumbnailUrl),
                  if (isLocked)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.lock, color: Colors.white70, size: 16),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrameImage extends StatelessWidget {
  const _FrameImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final isNetwork = path.startsWith('http');
    return ColoredBox(
      color: Colors.white,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _FrameImageFallback(),
            )
          : Image.asset(
              path,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const _FrameImageFallback(),
            ),
    );
  }
}

class _FrameImageFallback extends StatelessWidget {
  const _FrameImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_not_supported_outlined, color: Colors.black26),
    );
  }
}
