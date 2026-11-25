import 'dart:async';
import 'dart:io';

import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_cubit.dart';
import 'package:digipad_flutter/screens/features/visagismo/cubit/visagismo_state.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_catalog_repository.dart';
import 'package:digipad_flutter/screens/features/visagismo/data/visagismo_totem_link.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_measurements_from_mlkit.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/face_shape_classifier.dart';
import 'package:digipad_flutter/screens/features/visagismo/logic/frame_match.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/face_analysis_debug_sheet.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/face_shape_badge.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/frame_suggestions_list.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/glasses_try_on_view.dart';
import 'package:digipad_flutter/screens/features/visagismo/widgets/visagismo_labels.dart';
import 'package:digipad_flutter/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

/// Shows the captured photo, the classified face shape, and a horizontal
/// row of suggested reference frames for that shape.
///
/// The best-ranked frame is tried on the photo right away (drawn over the
/// eyes ML Kit found, see `GlassesTryOnView`); tapping another suggestion
/// swaps it, tapping the selected one removes it. "Enviar con este marco"
/// saves the photo WITH the glasses as a new gallery image and sends it to
/// the Tótem when connected — the plain photo is still saved/sent as before.
///
/// Every capture is saved straight to the app's internal gallery
/// (`GalleryStorage`). With a [totemLink] (DigiTower 3D Remote Control) it is
/// also sent to the Tótem when connected — right away, or as soon as the
/// Tótem gets paired from this screen. Without one (DigiTower 3D Premium,
/// which runs on the Tótem itself) every Tótem control is hidden.
class VisagismoResultScreen extends StatefulWidget {
  const VisagismoResultScreen({super.key, this.totemLink});

  final VisagismoTotemLink? totemLink;

  @override
  State<VisagismoResultScreen> createState() => _VisagismoResultScreenState();
}

class _VisagismoResultScreenState extends State<VisagismoResultScreen> {
  // Tracks which capture has already been saved/sent, so rebuilds don't
  // repeat either action for the same photo.
  String? _handledImagePath;

  // Sends the pending capture once a Tótem gets connected.
  StreamSubscription<VisagismoTotemStatus>? _linkSub;

  @override
  void initState() {
    super.initState();
    _linkSub = widget.totemLink?.statusChanges
        .where((s) => s.connected)
        .listen((_) {
          if (mounted) _handleNewCapture(context);
        });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  // Try-on: the frame shown on the photo. Until the operator picks one, the
  // best suggestion is used ([_userPickedFrame] false).
  final _tryOnKey = GlobalKey<GlassesTryOnViewState>();
  bool _userPickedFrame = false;
  FrameCatalogItem? _pickedFrame;
  String? _tryOnPhotoPath;
  bool _savingTryOn = false;

  FrameCatalogItem? _tryOnFrame(
    String? imagePath,
    FaceShapeResult? result,
    List<RankedFrame> frames,
  ) {
    if (imagePath != _tryOnPhotoPath) {
      // New photo: back to the automatic choice.
      _tryOnPhotoPath = imagePath;
      _userPickedFrame = false;
      _pickedFrame = null;
    }
    if (_userPickedFrame) return _pickedFrame;
    if (result == null) return null;
    // The best match is tried on right away.
    return frames.map((f) => f.item).where(canTryOn).firstOrNull;
  }

  Future<void> _saveTryOn(BuildContext context, FrameCatalogItem frame) async {
    if (_savingTryOn) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final name = frameName(l10n, frame);
    final link = widget.totemLink;
    setState(() => _savingTryOn = true);
    try {
      final png = await _tryOnKey.currentState?.renderPng();
      if (png == null) return;
      final dir = await _galleryDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/visagismo_${frame.frameId}_$stamp.png');
      await file.writeAsBytes(png, flush: true);
      await GalleryStorage().saveImage(file);

      final sent = link != null && link.status.connected
          ? await link.send(file)
          : false;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? l10n.visagismoTryOnSent(name)
                : l10n.visagismoTryOnSaved(name),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Visagismo] try-on export failed: $e');
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.visagismoTryOnSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _savingTryOn = false);
    }
  }

  // The permanent copy of the current capture and whether the Tótem got it.
  File? _keptPhoto;
  bool _keptPhotoSent = false;

  /// Saves a new capture to the gallery and sends it when connected; on a
  /// later call (e.g. the Tótem was paired after the capture) sends the copy
  /// that is still pending. Results are shown as snackbars.
  Future<void> _handleNewCapture(BuildContext context) async {
    final imagePath = context.read<VisagismoCubit>().state.capturedImagePath;
    if (imagePath == null || imagePath.isEmpty) return;

    // Read before the `await` — this widget may be disposed by the time the
    // save finishes, and `context` must not be touched after that gap.
    final link = widget.totemLink;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    if (imagePath != _handledImagePath) {
      _handledImagePath = imagePath;
      _keptPhoto = null;
      _keptPhotoSent = false;
      final photo = await _keepCapture(imagePath);
      await GalleryStorage().saveImage(photo);
      if (_handledImagePath != imagePath) return; // a newer capture took over
      _keptPhoto = photo;
      if (link == null || !link.status.connected) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.visagismoPhotoSaved)),
        );
        return;
      }
    }
    if (link != null) await _sendKeptPhoto(link, messenger, l10n);
  }

  Future<void> _sendKeptPhoto(
    VisagismoTotemLink link,
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
  ) async {
    final photo = _keptPhoto;
    final status = link.status;
    if (photo == null || _keptPhotoSent || !status.connected) return;
    _keptPhotoSent = true; // before the await: no double sends
    final ok = await link.send(photo);
    if (!ok) _keptPhotoSent = false;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.visagismoPhotoSavedAndSent(status.totemName ?? '')
              : l10n.visagismoPhotoSendFailed,
        ),
      ),
    );
  }

  /// Where visagismo photos that go to the gallery live. The gallery stores
  /// only the PATH (and hides entries whose file is gone), so they must be
  /// somewhere permanent — not the camera's cache dir.
  static Future<Directory> _galleryDir() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/visagismo',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// A permanent copy of the camera capture at [capturePath]. The capture
  /// itself is a temp file: "Repetir" deletes it (`retakePhoto`) and the OS
  /// may clear the cache, either of which used to make the photo silently
  /// vanish from the gallery. Falls back to the capture if the copy fails, so
  /// the photo is still saved and sent like before.
  static Future<File> _keepCapture(String capturePath) async {
    final capture = File(capturePath);
    try {
      final dir = await _galleryDir();
      final name = capture.uri.pathSegments.last;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      return await capture.copy('${dir.path}/visagismo_${stamp}_$name');
    } catch (e) {
      debugPrint('[Visagismo] could not keep the capture: $e');
      return capture;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Capture just arrived — save (+ send) right away. A Tótem paired later
    // is handled by [_linkSub].
    return BlocListener<VisagismoCubit, VisagismoState>(
      listenWhen: (p, c) => p.capturedImagePath != c.capturedImagePath,
      listener: (context, state) => _handleNewCapture(context),
      child: Builder(
        builder: (context) {
          // Covers the case where this screen mounts with a capture already
          // present and the Tótem already connected.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleNewCapture(context);
          });
          return _buildBody(context);
        },
      ),
    );
  }

  /// What to tell the operator when the photo could not be classified.
  static String _issueMessage(AppLocalizations l10n, FaceCaptureIssue? issue) =>
      switch (issue) {
        FaceCaptureIssue.headTurned => l10n.visagismoIssueHeadTurned,
        FaceCaptureIssue.headTilted => l10n.visagismoIssueHeadTilted,
        FaceCaptureIssue.detectorError => l10n.visagismoIssueDetectorError,
        FaceCaptureIssue.noFace || null => l10n.visagismoIssueNoFace,
      };

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<VisagismoCubit, VisagismoState>(
      builder: (context, state) {
        final result = state.lastClassification;
        final imagePath = state.capturedImagePath;
        // Every frame, best match for this face first (client request
        // 2026-11-25: suggestions first, but the client can try any frame).
        final frames = rankFramesByMatch(state.catalog, result);

        final tryOnFrame = _tryOnFrame(imagePath, result, frames);

        return Column(
          children: [
            if (imagePath != null && imagePath.isNotEmpty)
              // Flexible instead of a fixed 3:4 box so the screen also fits
              // on short phones (the photo is cropped like BoxFit.cover).
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GlassesTryOnView(
                      key: _tryOnKey,
                      photoPath: imagePath,
                      anchor: state.lastAnalysis?.glasses,
                      frame: tryOnFrame,
                    ),
                    if (tryOnFrame != null)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: _TryOnBar(
                          totemLink: widget.totemLink,
                          saving: _savingTryOn,
                          onReset: () => _tryOnKey.currentState?.resetAdjust(),
                          onSave: () => _saveTryOn(context, tryOnFrame),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                // Long press: hidden diagnostics for the optician.
                child: GestureDetector(
                  onLongPress: () =>
                      showFaceAnalysisDebugSheet(context, state.lastAnalysis),
                  child: result != null
                      ? FaceShapeBadge(result: result)
                      : Text(
                          _issueMessage(
                            AppLocalizations.of(context),
                            state.lastAnalysis?.issue,
                          ),
                          style: const TextStyle(color: Colors.white70),
                        ),
                ),
              ),
            ),
            SizedBox(
              // Bigger cards on tablets / Tótem screens.
              height: MediaQuery.sizeOf(context).shortestSide >= 600
                  ? 220
                  : 168,
              child: FrameSuggestionsList(
                frames: frames,
                selectedFrameId: tryOnFrame?.frameId,
                onSelected: (item) => setState(() {
                  _userPickedFrame = true;
                  _pickedFrame = item;
                }),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

/// Over the photo: "reubicar" on the left, "enviar/guardar con marco" on
/// the right. The frame's name is on its card, not repeated here.
class _TryOnBar extends StatelessWidget {
  const _TryOnBar({
    required this.totemLink,
    required this.saving,
    required this.onReset,
    required this.onSave,
  });

  final VisagismoTotemLink? totemLink;
  final bool saving;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final link = totemLink;
    if (link == null) return _bar(context, connected: false);
    return StreamBuilder<VisagismoTotemStatus>(
      stream: link.statusChanges,
      initialData: link.status,
      builder: (context, snap) =>
          _bar(context, connected: snap.data?.connected ?? false),
    );
  }

  Widget _bar(BuildContext context, {required bool connected}) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: AppLocalizations.of(context).visagismoRecenterFrame,
          onPressed: onReset,
          icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  connected ? Icons.send_rounded : Icons.save_alt_rounded,
                  size: 18,
                ),
          label: Text(
            connected
                ? AppLocalizations.of(context).visagismoSendWithFrame
                : AppLocalizations.of(context).visagismoSaveWithFrame,
          ),
        ),
      ],
    );
  }
}

/// App bar actions while showing a result (used by `VisagismoEntryScreen`):
/// with a [totemLink], the Tótem link — green when connected, a spinner while
/// a photo goes out, opens the pairing screen — then "Repetir" (retake) on the
/// far right.
class VisagismoResultActions extends StatelessWidget {
  const VisagismoResultActions({super.key, this.totemLink});

  final VisagismoTotemLink? totemLink;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VisagismoCubit>();
    final l10n = AppLocalizations.of(context);
    final link = totemLink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (link != null)
          StreamBuilder<VisagismoTotemStatus>(
            stream: link.statusChanges,
            initialData: link.status,
            builder: (context, snap) {
              final status = snap.data ?? VisagismoTotemStatus.disconnected;
              return IconButton(
                tooltip: status.connected
                    ? l10n.visagismoConnectedTo(status.totemName ?? '')
                    : l10n.visagismoConnectToTotem,
                onPressed: () => link.openPairing(context),
                icon: status.sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.wifi_tethering_rounded,
                        color: status.connected
                            ? const Color(0xFF00E676)
                            : Colors.white70,
                      ),
              );
            },
          ),
        IconButton(
          tooltip: l10n.visagismoRetake,
          onPressed: cubit.retakePhoto,
          icon: const Icon(Icons.replay),
        ),
      ],
    );
  }
}
