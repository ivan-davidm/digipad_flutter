import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:digipad_flutter/common/components/gallery_photo_strip.dart';
import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/features/photo_sync/cubit/client_cubit.dart';
import 'package:digipad_flutter/features/photo_sync/cubit/client_state.dart';
import 'package:digipad_flutter/screens/features/measurements/measurement_capture_screen.dart';

class ClientScreen extends StatelessWidget {
  const ClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: BlocBuilder<ClientCubit, ClientState>(
          builder: (context, state) {
            if (state is ClientScanning) return _buildScanner(context);
            if (state is ClientDiscovering) return _buildDiscovering(context, state);
            if (state is ClientConnecting) return _buildLoading('Conectando…');
            if (state is ClientConnected) return _buildConnected(context, state);
            if (state is ClientSendSuccess) return _buildSuccess(context, state);
            if (state is ClientError) return _buildError(context, state);
            return _buildLoading('Iniciando…');
          },
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: Colors.white60,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 20),
          Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 15)),
        ],
      ),
    );
  }

  // ── QR Scanner ────────────────────────────────────────────────────────────

  Widget _buildScanner(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(context, 'Escanear Tótem'),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Apuntá la cámara al código QR\nque muestra el Tótem',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: MobileScanner(
                onDetect: (capture) {
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw != null && raw.startsWith('digipad-totem')) {
                    context.read<ClientCubit>().pairWithToken(raw);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Discovering ────────────────────────────────────────────────────────────

  Widget _buildDiscovering(BuildContext context, ClientDiscovering state) {
    return Column(
      children: [
        _buildTopBar(
          context,
          'Buscando Tótem',
          trailing: TextButton(
            onPressed: () => context.read<ClientCubit>().forgetTotem(),
            child: const Text(
              'Cambiar',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          state.targetName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Buscando señal Bluetooth/WiFi Direct…\nasegurate de que el Tótem esté activo',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
        ),
        const Spacer(),
      ],
    );
  }

  // ── Connected ──────────────────────────────────────────────────────────────

  Widget _buildConnected(BuildContext context, ClientConnected state) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildTopBar(
            context,
            'Conectado',
            trailing: TextButton(
              onPressed: () => context.read<ClientCubit>().forgetTotem(),
              child: const Text(
                'Cambiar Tótem',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          ),
        ),

        // Connection chip
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF6C63FF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E676),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.endpointName,
                        style: const TextStyle(
                          color: Color(0xFFB5B0FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.sentCount > 0) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${state.sentCount} enviada${state.sentCount == 1 ? '' : 's'}',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Internal DigiPad gallery — live via GalleryStorage stream
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: StreamBuilder<List<File>>(
              stream: GalleryStorage.instance.watchImages(),
              builder: (context, snap) {
                final images = snap.data ?? [];
                return _InternalGalleryCard(
                  images: images,
                  isSending: state.isSending,
                  onTapImage: (file) =>
                      context.read<ClientCubit>().sendFile(file),
                );
              },
            ),
          ),
        ),

        // Camera button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _ActionButton(
              icon: Icons.camera_alt_rounded,
              label: 'Tomar foto y enviar',
              subtitle: 'Abre la cámara y envía al Tótem automáticamente',
              color: const Color(0xFF6C63FF),
              loading: state.isSending,
              onTap: () {
                final cubit = context.read<ClientCubit>();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MeasurementCaptureScreen(
                    onPhotoCaptured: (path) {
                      if (!cubit.isClosed) cubit.sendFile(File(path));
                    },
                  ),
                ));
              },
            ),
          ),
        ),

        // Gallery button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: _ActionButton(
              icon: Icons.photo_library_rounded,
              label: 'Galería del dispositivo',
              subtitle: 'Elegir una foto existente y enviarla',
              color: const Color(0xFFE91E8C),
              loading: state.isSending,
              onTap: () => context.read<ClientCubit>().sendFromGallery(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Success ────────────────────────────────────────────────────────────────

  Widget _buildSuccess(BuildContext context, ClientSendSuccess state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF00E676), size: 60),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Foto enviada! (${state.totalSent})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recibida en el Tótem',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, ClientError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 64),
            const SizedBox(height: 20),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 28),
            if (state.lastTotemName != null) ...[
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<ClientCubit>().retryDiscovery(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextButton(
              onPressed: () => context.read<ClientCubit>().forgetTotem(),
              child: const Text(
                'Escanear nuevo QR',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Internal gallery card ──────────────────────────────────────────────────────

class _InternalGalleryCard extends StatelessWidget {
  final List<File> images;
  final bool isSending;
  final void Function(File) onTapImage;

  const _InternalGalleryCard({
    required this.images,
    required this.isSending,
    required this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFFB8C00).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_rounded,
                  color: Color(0xFFFB8C00), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Galería interna DigiPad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${images.length} foto${images.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (images.isEmpty)
            const Text(
              'No hay fotos guardadas todavía',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            )
          else
            GalleryPhotoStrip(
              photos: images,
              onTap: isSending ? null : onTapImage,
              onDelete: (file) => GalleryStorage.instance.deleteImage(file),
              onDeleteMultiple: (files) async {
                for (final f in files) {
                  await GalleryStorage.instance.deleteImage(f);
                }
              },
            ),
        ],
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        opacity: loading ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.18),
                color.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: color.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      )
                    : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white24, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
