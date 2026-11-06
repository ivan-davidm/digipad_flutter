import 'dart:io';
import 'dart:typed_data';

import 'package:digipad_flutter/screens/features/virtual_mirror/cubit/virtual_mirror_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class GallerySection extends StatefulWidget {
  final List<File> gallery;

  const GallerySection({super.key, required this.gallery});

  @override
  State<GallerySection> createState() => _GalleryCardState();
}

class _GalleryCardState extends State<GallerySection> {
  final _controller = ScrollController();

  // ── Multi-select state ─────────────────────────────────────────────────────
  bool _selecting = false;
  final Set<String> _selected = {};

  void _enterSelect(File file) {
    setState(() {
      _selecting = true;
      _selected.add(file.path);
    });
  }

  void _toggleSelect(File file) {
    setState(() {
      if (_selected.contains(file.path)) {
        _selected.remove(file.path);
        if (_selected.isEmpty) _selecting = false;
      } else {
        _selected.add(file.path);
      }
    });
  }

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  Future<bool> _confirmDelete(BuildContext context, int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.grey.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Text(
              count == 1
                  ? context.l10n.galleryDeleteTitle
                  : 'Eliminar $count fotos',
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              count == 1
                  ? context.l10n.galleryDeleteContent
                  : '¿Eliminar las $count fotos seleccionadas?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  context.l10n.cancel,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  context.l10n.delete,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void scrollLeft() {
    _controller.animateTo(
      _controller.offset - 220,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void scrollRight() {
    _controller.animateTo(
      _controller.offset + 220,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade600, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Selection action bar ────────────────────────────────────────
            if (_selecting)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _selected.length == 1
                          ? context.l10n.vmSelectedCountOne(_selected.length)
                          : context.l10n.vmSelectedCountOther(_selected.length),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final files = widget.gallery
                            .where((f) => _selected.contains(f.path))
                            .toList();
                        if (files.isEmpty) return;
                        final ok = await _confirmDelete(context, files.length);
                        if (ok && context.mounted) {
                          await context
                              .read<VirtualMirrorCubit>()
                              .deleteMultiple(files);
                          _exitSelect();
                        }
                      },
                      icon: const Icon(Icons.delete_rounded,
                          size: 16, color: Colors.redAccent),
                      label: Text(context.l10n.delete,
                          style: const TextStyle(color: Colors.redAccent)),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                    ),
                    TextButton(
                      onPressed: _exitSelect,
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      child: Text(context.l10n.cancel,
                          style: const TextStyle(color: Colors.white38)),
                    ),
                  ],
                ),
              ),

            // ── Scrollable gallery ──────────────────────────────────────────
            SizedBox(
              height: 250,
              child: Stack(
                children: [
                  NotificationListener<UserScrollNotification>(
                    onNotification: (_) => true,
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      itemCount: widget.gallery.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final file = widget.gallery[index];
                        final isSelected = _selected.contains(file.path);

                        return _SelectableDraggableThumbnail(
                          file: file,
                          isSelecting: _selecting,
                          isSelected: isSelected,
                          onLongPress: () => _enterSelect(file),
                          onTapInSelectMode: () => _toggleSelect(file),
                          onDelete: () async {
                            final ok = await _confirmDelete(context, 1);
                            if (ok && context.mounted) {
                              await context
                                  .read<VirtualMirrorCubit>()
                                  .deleteImage(file);
                            }
                          },
                        );
                      },
                    ),
                  ),

                  // Scroll arrows
                  Positioned(
                    left: 0,
                    top: 100,
                    child: _ArrowButton(
                      icon: Icons.arrow_back_ios,
                      onTap: scrollLeft,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 100,
                    child: _ArrowButton(
                      icon: Icons.arrow_forward_ios,
                      onTap: scrollRight,
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

// ── Thumbnail with drag, X delete, and select overlay ─────────────────────────

class _SelectableDraggableThumbnail extends StatelessWidget {
  final File file;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onTapInSelectMode;
  final VoidCallback onDelete;

  const _SelectableDraggableThumbnail({
    required this.file,
    required this.isSelecting,
    required this.isSelected,
    required this.onLongPress,
    required this.onTapInSelectMode,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: isSelecting
          ? null
          : (details) {
              Scrollable.of(context).position.moveTo(
                    Scrollable.of(context).position.pixels - details.delta.dx,
                  );
            },
      onLongPress: isSelecting ? null : onLongPress,
      onTap: isSelecting ? onTapInSelectMode : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFF6C63FF), width: 3)
              : Border.all(color: Colors.transparent, width: 3),
        ),
        child: Stack(
          children: [
            // Drag handle (only when not selecting)
            if (!isSelecting)
              LongPressDraggable<File>(
                data: file,
                delay: const Duration(milliseconds: 300),
                feedback: Opacity(
                  opacity: 0.7,
                  child: _ThumbnailPreview(file: file),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _ThumbnailPreview(file: file),
                ),
                child: _ThumbnailPreview(file: file),
              )
            else
              _ThumbnailPreview(file: file),

            // Checkbox overlay in select mode
            if (isSelecting)
              Positioned(
                top: 6,
                left: 6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : Colors.black54,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white60, width: 1.5),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 15)
                      : null,
                ),
              ),

            // X delete button (only when not in select mode)
            if (!isSelecting)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPreview extends StatefulWidget {
  final File file;

  const _ThumbnailPreview({required this.file});

  @override
  State<_ThumbnailPreview> createState() => _ThumbnailPreviewState();
}

class _ThumbnailPreviewState extends State<_ThumbnailPreview> {
  Uint8List? _thumbnailBytes;
  bool _isLoading = false;

  bool get _isVideo {
    final ext = widget.file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _generateThumbnail();
    }
  }

  @override
  void didUpdateWidget(_ThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      if (_isVideo) {
        _generateThumbnail();
      } else {
        setState(() => _thumbnailBytes = null);
      }
    }
  }

  Future<void> _generateThumbnail() async {
    setState(() => _isLoading = true);
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );
      if (mounted) {
        setState(() {
          _thumbnailBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 200,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _isVideo
            ? Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (_thumbnailBytes != null)
                    Image.memory(_thumbnailBytes!, fit: BoxFit.cover)
                  else
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Icon(
                          Icons.videocam,
                          color: Colors.white24,
                          size: 64,
                        ),
                      ),
                    ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ],
              )
            : Image.file(widget.file, fit: BoxFit.cover),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 40,
        backgroundColor: Colors.grey.shade800,
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
