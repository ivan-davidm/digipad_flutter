import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:digipad_flutter/common/components/gallery_photo_strip.dart';
import 'package:digipad_flutter/data/local/gallery_storage.dart';
import 'package:digipad_flutter/features/photo_sync/cubit/totem_cubit.dart';
import 'package:digipad_flutter/features/photo_sync/cubit/totem_state.dart';

class TotemScreen extends StatefulWidget {
  const TotemScreen({super.key});

  @override
  State<TotemScreen> createState() => _TotemScreenState();
}

class _TotemScreenState extends State<TotemScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TotemCubit>().startTotem();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: BlocBuilder<TotemCubit, TotemState>(
          builder: (context, state) {
            return Column(
              children: [
                _buildTopBar(context, state),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TotemState state) {
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
          const Expanded(
            child: Text(
              'Modo Tótem',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (state is TotemActive)
            TextButton.icon(
              onPressed: () async {
                await context.read<TotemCubit>().stopTotem();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: const Text('Detener'),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, TotemState state) {
    if (state is TotemStarting) return _buildLoading();
    if (state is TotemError) return _buildError(context, state);
    if (state is TotemActive) return _buildActive(context, state);
    // TotemIdle — waiting for startTotem()
    return _buildLoading();
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFA6)),
          ),
          SizedBox(height: 20),
          Text(
            'Iniciando Tótem…',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// QR payload.
  ///  - With a LAN server: `digipad-totem/v2 <base64 json {name,hosts,port}>`
  ///    (a v2 client tries LAN first, then falls back to Nearby).
  ///  - Without LAN: the legacy `digipad-totem:{name}` string, so behaviour is
  ///    byte-identical to the previous version.
  String _qrData(TotemActive state) {
    if (state.lanHosts.isEmpty && state.lanPort == 0) {
      return 'digipad-totem:${state.totemName}';
    }
    final payload = jsonEncode({
      'name': state.totemName,
      'hosts': state.lanHosts,
      'port': state.lanPort,
    });
    return 'digipad-totem/v2 ${base64.encode(utf8.encode(payload))}';
  }

  Widget _buildActive(BuildContext context, TotemActive state) {
    final qrData = _qrData(state);
    final clientCount = state.connectedClientIds.length;
    final lanIps = state.lanHosts
        .map((h) => h.replaceFirst('http://', ''))
        .toList();
    final transport = state.lanOk && state.nearbyOk
        ? 'WiFi local + Bluetooth (Nearby)'
        : state.lanOk
            ? 'WiFi local'
            : 'Bluetooth (Nearby)';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // ── Status chips ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatusChip(
                icon: Icons.wifi_tethering_rounded,
                label: 'Transmitiendo',
                color: const Color(0xFF00E676),
              ),
              const SizedBox(width: 12),
              _StatusChip(
                icon: Icons.people_alt_rounded,
                label: '$clientCount operador${clientCount == 1 ? '' : 'es'}',
                color: clientCount > 0
                    ? const Color(0xFF6C63FF)
                    : Colors.white38,
              ),
              const SizedBox(width: 12),
              _StatusChip(
                icon: Icons.photo_library_rounded,
                label: '${state.photoCount} 📷',
                color: const Color(0xFF00BFA6),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── QR code ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BFA6).withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // ── Totem name ────────────────────────────────────────────────────
          Text(
            state.totemName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Mostrá este código al Operador',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 32),

          // ── Connection info ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.settings_input_antenna_rounded,
                  label: 'Conexión',
                  value: transport,
                ),
                if (lanIps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.wifi_rounded,
                    label: 'WiFi local',
                    value: lanIps.join('  ·  '),
                  ),
                ],
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.qr_code_rounded,
                  label: 'ID del Tótem',
                  value: state.totemName,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.link_rounded,
                  label: 'Operadores conectados',
                  value: clientCount > 0
                      ? '$clientCount activo${clientCount == 1 ? '' : 's'}'
                      : 'Ninguno aún',
                ),
                if (!state.nearbyOk && state.lanOk) ...[
                  const SizedBox(height: 10),
                  const _InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Nota',
                    value: 'Bluetooth no disponible — usando solo WiFi local',
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Received photos — live via GalleryStorage stream ──────────────
          StreamBuilder<List<File>>(
            stream: GalleryStorage.instance.watchImages(),
            builder: (context, snap) {
              final photos = snap.data ?? [];
              if (photos.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_rounded,
                            color: Color(0xFF00BFA6), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Fotos recibidas (${photos.length})',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GalleryPhotoStrip(
                    photos: photos,
                    itemSize: 100,
                    onDelete: (f) => GalleryStorage.instance.deleteImage(f),
                    onDeleteMultiple: (files) async {
                      for (final f in files) {
                        await GalleryStorage.instance.deleteImage(f);
                      }
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Stop button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.read<TotemCubit>().stopTotem();
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Detener Tótem'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, TotemError state) {
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
            ElevatedButton.icon(
              onPressed: () => context.read<TotemCubit>().startTotem(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

