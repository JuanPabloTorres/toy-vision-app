import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/components/tobi_mascot.dart';
import '../feedback/animation_director.dart';

class Tobi3dStage extends ConsumerStatefulWidget {
  const Tobi3dStage({
    super.key,
    this.enable3d = true,
    this.fallbackSize = 150,
  });

  final bool enable3d;
  final double fallbackSize;

  @override
  ConsumerState<Tobi3dStage> createState() => _Tobi3dStageState();
}

class _Tobi3dStageState extends ConsumerState<Tobi3dStage> {
  final Flutter3DController _controller = Flutter3DController();
  bool _loaded = false;
  bool _failed = false;

  bool get _platformSupports3d =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    ref.listen<AnimationPresentationState>(animationDirectorProvider,
        (previous, next) {
      if (_loaded && previous?.sequence != next.sequence) {
        _controller.playAnimation(animationName: next.modelAnimation);
      }
    });
    final animation = ref.watch(animationDirectorProvider);
    final threeDimensionalRenderingEnabled = ref.watch(tobi3dEnabledProvider);
    if (!widget.enable3d ||
        !threeDimensionalRenderingEnabled ||
        !_platformSupports3d ||
        _failed) {
      return Semantics(
        label: 'Tobi',
        child: TobiMascot(
          size: widget.fallbackSize,
          motion: _motionFor(animation.tobiState),
        ),
      );
    }
    return Semantics(
      label: 'Tobi 3D',
      child: Flutter3DViewer(
        src: 'assets/models/tobi.gltf',
        controller: _controller,
        enableTouch: false,
        activeGestureInterceptor: false,
        progressBarColor: Colors.transparent,
        onLoad: (_) {
          if (!mounted) return;
          _loaded = true;
          _controller.playAnimation(animationName: animation.modelAnimation);
        },
        onError: (_) {
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
  }

  TobiMotion _motionFor(TobiState state) => switch (state) {
        TobiState.searching => TobiMotion.searching,
        TobiState.foundToy => TobiMotion.found,
        TobiState.encouraging => TobiMotion.encouraging,
        TobiState.celebrating || TobiState.finished => TobiMotion.celebrating,
        TobiState.confused => TobiMotion.confused,
        TobiState.idle => TobiMotion.idle,
      };
}

final tobi3dEnabledProvider = Provider<bool>((ref) => true);
