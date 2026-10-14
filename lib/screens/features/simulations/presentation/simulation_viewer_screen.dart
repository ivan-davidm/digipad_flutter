import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:digipad_flutter/l10n/l10n.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/simulations_cubit.dart';
import '../cubit/simulations_state.dart';
import '../models/simulation_scenario.dart';
import 'widgets/simulation_canvas.dart';
import 'widgets/simulation_control_panel.dart';
import 'widgets/simulation_top_bar.dart';

/// Screen that displays the simulation with draggable lens effect.
class SimulationViewerScreen extends StatefulWidget {
  final SimulationCategory category;
  final SimulationScenario scenario;

  const SimulationViewerScreen({
    super.key,
    required this.category,
    required this.scenario,
  });

  @override
  State<SimulationViewerScreen> createState() => _SimulationViewerScreenState();
}

class _SimulationViewerScreenState extends State<SimulationViewerScreen>
    with TickerProviderStateMixin {
  ui.Image? _problemImage;
  ui.Image? _correctedImage;
  String? _errorMessage;
  bool _isLoading = true;

  late AnimationController _pulseController;
  late Animation<double> pulseAnimation;

  /// Drives the photochromic activation fade (0 = clear, 1 = fully activated).
  late AnimationController _adaptController;
  PhotoAdaptSpeed _adaptSpeed = PhotoAdaptSpeed.buena;

  bool get _isPhotochromic => widget.category.id == 'photochromic';

  CorrectionLens? _currentLens;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _adaptController = AnimationController(
      vsync: this,
      duration: _adaptSpeed.duration,
      value: 1.0,
    );

    // Set initial lens
    if (widget.scenario.correctionLenses.isNotEmpty) {
      // Progressives (multifocal) default to the "Good" quality tier.
      _currentLens = widget.category.id == 'multifocal'
          ? widget.scenario.correctionLenses.firstWhere(
              (lens) => lens.quality == LensQuality.good,
              orElse: () => widget.scenario.correctionLenses.first,
            )
          : widget.scenario.correctionLenses.first;
    }

    _loadImages();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _adaptController.dispose();
    super.dispose();
  }

  void _playAdaptation() {
    _adaptController
      ..duration = _adaptSpeed.duration
      ..forward(from: 0.0);
  }

  void _onAdaptSpeedChanged(PhotoAdaptSpeed speed) {
    setState(() => _adaptSpeed = speed);
    if (_isPhotochromic &&
        _currentLens != null &&
        _currentLens!.name != 'sin_lente') {
      _playAdaptation();
    }
  }

  Future<void> _loadImages() async {
    setState(() => _isLoading = true);

    try {
      _problemImage = await _loadImage(widget.scenario.problemImagePath);

      // 'sin_lente' shows only the problem image (no correction)
      if (_currentLens != null && _currentLens!.name != 'sin_lente') {
        _correctedImage = await _loadImage(_currentLens!.correctedImagePath);
      } else {
        _correctedImage = null;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading images: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _onLensChanged(CorrectionLens lens) async {
    // Re-tapping the active photochromic lens simply replays the fade.
    if (_currentLens?.id == lens.id) {
      if (_isPhotochromic && lens.name != 'sin_lente') _playAdaptation();
      return;
    }

    setState(() {
      _currentLens = lens;
      _isLoading = true;
    });

    try {
      // 'sin_lente' shows only the problem image (no correction overlay)
      if (lens.name == 'sin_lente') {
        _correctedImage = null;
        _adaptController.value = 1.0;
      } else {
        _correctedImage = await _loadImage(lens.correctedImagePath);
        if (_isPhotochromic) {
          _playAdaptation();
        } else {
          _adaptController.value = 1.0;
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading lens image: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onToggleInteractionMode(BuildContext cubitContext) {
    cubitContext.read<SimulationsCubit>().toggleInteractionMode();
  }

  void _onLensDragStart(Offset position, BuildContext cubitContext) {
    final size = MediaQuery.of(context).size;
    final lensRadius = cubitContext.read<SimulationsCubit>().state.lensRadius;

    // Clamp position within screen bounds
    final clampedPosition = Offset(
      position.dx.clamp(lensRadius, size.width - lensRadius),
      position.dy.clamp(lensRadius, size.height - lensRadius),
    );

    cubitContext.read<SimulationsCubit>().moveLens(clampedPosition);
    cubitContext.read<SimulationsCubit>().setDragging(true);
  }

  void _onLensDragUpdate(Offset position, BuildContext cubitContext) {
    final size = MediaQuery.of(context).size;
    final lensRadius = cubitContext.read<SimulationsCubit>().state.lensRadius;

    // Clamp position within screen bounds
    final clampedPosition = Offset(
      position.dx.clamp(lensRadius, size.width - lensRadius),
      position.dy.clamp(lensRadius, size.height - lensRadius),
    );

    cubitContext.read<SimulationsCubit>().moveLens(clampedPosition);
  }

  void _onLensDragEnd(BuildContext cubitContext) {
    cubitContext.read<SimulationsCubit>().setDragging(false);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SimulationsCubit();
        cubit.selectCategory(widget.category);
        cubit.selectScenario(widget.scenario);
        if (_currentLens != null) {
          cubit.selectLens(_currentLens!);
        }

        // Center lens after initial layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final size = MediaQuery.of(context).size;
            cubit.setLensPosition(Offset(size.width / 2, size.height / 2));
          }
        });

        return cubit;
      },
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_isLoading || _problemImage == null) {
      return _buildLoadingView();
    }

    return BlocBuilder<SimulationsCubit, SimulationsState>(
      builder: (context, state) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Main simulation canvas
            AnimatedBuilder(
              animation: _adaptController,
              builder: (context, _) => SimulationCanvas(
                state: state,
                category: widget.category,
                problemImage: _problemImage!,
                correctedImage: _correctedImage,
                currentLens: _currentLens,
                onLensDragStart: (pos) => _onLensDragStart(pos, context),
                onLensDragUpdate: (pos) => _onLensDragUpdate(pos, context),
                onLensDragEnd: () => _onLensDragEnd(context),
                adaptationProgress:
                    _isPhotochromic ? _adaptController.value : 1.0,
              ),
            ),

            // Top gradient and back button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SimulationTopBar(
                scenario: widget.scenario,
                category: widget.category,
                categoryColor: widget.category.color,
                onBack: () => Navigator.pop(context),
                onToggleMode: () => _onToggleInteractionMode(context),
                isLensMode: state.isLensDraggingMode,
              ),
            ),

            // Bottom control panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SimulationControlPanel(
                state: state,
                category: widget.category,
                scenario: widget.scenario,
                selectedLens: _currentLens,
                onLensSelected: _onLensChanged,
                adaptSpeed: _adaptSpeed,
                onAdaptSpeedChanged: _onAdaptSpeedChanged,
                onReplayAdaptation: _playAdaptation,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.goBack),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            context.l10n.loadingSimulation,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
