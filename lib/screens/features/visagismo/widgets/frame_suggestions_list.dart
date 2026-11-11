import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/frame_color_picker_sheet.dart';
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

class _FrameCard extends StatefulWidget {
  const _FrameCard({required this.item, required this.isLocked});

  final FrameCatalogItem item;
  final bool isLocked;

  @override
  State<_FrameCard> createState() => _FrameCardState();
}

class _FrameCardState extends State<_FrameCard> {
  FrameColorOption? _chosenColor;

  Future<void> _onTap() async {
    if (widget.isLocked) return;
    final chosen = await FrameColorPickerSheet.show(
      context,
      frameName: widget.item.displayName,
    );
    if (chosen != null && mounted) setState(() => _chosenColor = chosen);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isLocked = widget.isLocked;
    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: 150,
          decoration: BoxDecoration(
            color: const Color(0xFF232329),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _chosenColor != null
                  ? Colors.deepPurpleAccent
                  : Colors.white24,
              width: _chosenColor != null ? 1.6 : 1,
            ),
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
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.lock,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_chosenColor != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _chosenColor!.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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
