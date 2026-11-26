import 'dart:io';

import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

/// Where the photo comes from when the host app turned the camera off
/// (`VisagismoCubit.cameraEnabled == false`): the app's internal gallery or
/// the device's gallery, like the other modules. Picking a photo starts the
/// scan right away (client request 2026-11-26: avoid the Tótem's low-quality
/// webcams for now).
class VisagismoPhotoSourceScreen extends StatefulWidget {
  const VisagismoPhotoSourceScreen({super.key});

  @override
  State<VisagismoPhotoSourceScreen> createState() =>
      _VisagismoPhotoSourceScreenState();
}

class _VisagismoPhotoSourceScreenState
    extends State<VisagismoPhotoSourceScreen> {
  bool _busy = false;

  Future<void> _pickFromDevice() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Same limit as the other modules; the face analysis uses ratios, so
        // the resolution doesn't change the result.
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (image == null || !mounted) return;
      context.read<VisagismoCubit>().onPhotoPicked(image.path);
    } catch (e) {
      debugPrint('[Visagismo] device gallery failed: $e');
      if (mounted) _showPickFailed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromInternal() async {
    if (_busy) return;
    final file = await showDialog<File>(
      context: context,
      builder: (_) => const VisagismoInternalGalleryDialog(),
    );
    if (file == null || !mounted) return;
    context.read<VisagismoCubit>().onPhotoPicked(file.path);
  }

  void _showPickFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).visagismoPickFailed),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLarge = MediaQuery.sizeOf(context).shortestSide >= 600;
    final tiles = [
      _SourceTile(
        icon: Icons.sd_storage_outlined,
        label: l10n.visagismoInternalGallery,
        color: Colors.tealAccent,
        onTap: _pickFromInternal,
      ),
      _SourceTile(
        icon: Icons.photo_library_outlined,
        label: l10n.visagismoDeviceGallery,
        color: Colors.blueAccent,
        onTap: _pickFromDevice,
      ),
    ];
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.face_retouching_natural,
                  color: Colors.deepPurpleAccent.shade100,
                  size: isLarge ? 72 : 56,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.visagismoPickPhotoTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isLarge ? 26 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.visagismoPickPhotoHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: isLarge ? 17 : 14,
                  ),
                ),
                SizedBox(height: isLarge ? 40 : 28),
                SizedBox(
                  height: isLarge ? 200 : 150,
                  child: Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 16),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    color: Colors.deepPurpleAccent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Same look as the measurements hub tiles.
class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final iconSize = (constraints.maxHeight * 0.32).clamp(36.0, 80.0);
            final fontSize = (constraints.maxHeight * 0.1).clamp(14.0, 22.0);
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: iconSize),
                  SizedBox(height: constraints.maxHeight * 0.06),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The app's internal gallery (`GalleryStorage`: photos received by the
/// Tótem, captures, saved try-ons). Pops with the chosen [File]. Read-only on
/// purpose — deleting photos is the other modules' job.
class VisagismoInternalGalleryDialog extends StatefulWidget {
  const VisagismoInternalGalleryDialog({super.key});

  @override
  State<VisagismoInternalGalleryDialog> createState() =>
      _VisagismoInternalGalleryDialogState();
}

class _VisagismoInternalGalleryDialogState
    extends State<VisagismoInternalGalleryDialog> {
  static const _videoExtensions = {'.mp4', '.mov', '.m4v', '.3gp', '.webm'};

  late final Future<List<File>> _images = _load();

  static Future<List<File>> _load() async {
    final storage = GalleryStorage();
    await storage.init();
    final files = await storage.loadImages();
    // The gallery also lists the virtual mirror's videos.
    return files.where((f) {
      final path = f.path.toLowerCase();
      return !_videoExtensions.any(path.endsWith);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final columns = size.shortestSide >= 600 ? 4 : 3;
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade700),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: size.width * 0.85,
        height: size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.visagismoInternalGallery,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<File>>(
                future: _images,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurpleAccent,
                      ),
                    );
                  }
                  final images = snap.data ?? const <File>[];
                  if (images.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography,
                            size: 56,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.visagismoGalleryEmpty,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white38),
                          ),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      final file = images[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(context).pop(file),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Colors.black26,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
