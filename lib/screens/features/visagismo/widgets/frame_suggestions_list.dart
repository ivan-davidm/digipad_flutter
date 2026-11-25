import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_match.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/visagismo_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Colour and label of each match level, best first: green, yellow, orange,
/// red (client request 2026-11-25: show every frame, ideal ones first, colour
/// says how well it suits the face; the client picks what they like).
extension FrameMatchLevelStyle on FrameMatchLevel {
  Color get color => switch (this) {
    FrameMatchLevel.ideal => const Color(0xFF22C55E),
    FrameMatchLevel.good => const Color(0xFFFACC15),
    FrameMatchLevel.possible => const Color(0xFFF97316),
    FrameMatchLevel.notRecommended => const Color(0xFFEF4444),
  };
}

/// Horizontal, side-scrollable row with EVERY frame, best match first, each
/// card marked with its match colour. With [onSelected], tapping a frame
/// tries it on the captured photo (`GlassesTryOnView`); tapping the selected
/// one again clears it.
class FrameSuggestionsList extends StatelessWidget {
  const FrameSuggestionsList({
    super.key,
    required this.frames,
    this.selectedFrameId,
    this.onSelected,
  });

  final List<RankedFrame> frames;
  final String? selectedFrameId;

  /// Called with the tapped frame, or null when the selected one is tapped.
  final ValueChanged<FrameCatalogItem?>? onSelected;

  @override
  Widget build(BuildContext context) {
    if (frames.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).visagismoNoFrames,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    final cubit = context.read<VisagismoCubit>();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: frames.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final ranked = frames[index];
        final item = ranked.item;
        return FutureBuilder<bool>(
          future: cubit.isFrameUnlocked(item),
          builder: (context, snapshot) {
            final unlocked = snapshot.data ?? item.isGeneric;
            final selected = item.frameId == selectedFrameId;
            final onSelected = this.onSelected;
            return GestureDetector(
              onTap: onSelected == null || !unlocked
                  ? null
                  : () => onSelected(selected ? null : item),
              child: _FrameCard(
                item: item,
                level: ranked.level,
                isLocked: !unlocked,
                selected: selected,
              ),
            );
          },
        );
      },
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({
    required this.item,
    required this.level,
    required this.isLocked,
    required this.selected,
  });

  final FrameCatalogItem item;
  final FrameMatchLevel? level;
  final bool isLocked;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levelColor = level?.color;
    final detail = frameDetail(l10n, item);
    return Opacity(
      opacity: isLocked ? 0.45 : 1.0,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white
                : (levelColor ?? Colors.white24).withValues(alpha: 0.9),
            width: selected ? 3 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colour only (client request 2026-11-25); the label stays for
            // screen readers.
            if (levelColor != null)
              Semantics(
                label: matchLevelName(l10n, level!),
                child: Container(height: 6, color: levelColor),
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFFF4F4F6),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: _FrameImage(path: item.thumbnailUrl),
                    ),
                  ),
                  if (isLocked)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.lock, color: Colors.black45, size: 16),
                    ),
                  if (selected)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.check_circle,
                        color: Color(0xFF7C3AED),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frameName(l10n, item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.15,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                      ),
                    ),
                ],
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
    return path.startsWith('http')
        ? Image.network(
            path,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _FrameImageFallback(),
          )
        : Image.asset(
            path,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const _FrameImageFallback(),
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
