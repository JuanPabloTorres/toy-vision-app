import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import '../feedback/animation_director.dart';

class RiveRewardEffect extends ConsumerStatefulWidget {
  const RiveRewardEffect({super.key});

  @override
  ConsumerState<RiveRewardEffect> createState() => _RiveRewardEffectState();
}

class _RiveRewardEffectState extends ConsumerState<RiveRewardEffect> {
  late final FileLoader _loader = FileLoader.fromAsset(
    'assets/rive/rewards.riv',
    riveFactory: Factory.flutter,
  );
  RiveWidgetController? _controller;
  int _firedSequence = -1;

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AnimationPresentationState>(
      animationDirectorProvider,
      (_, next) => _fire(next),
    );
    return IgnorePointer(
      child: RiveWidgetBuilder(
        fileLoader: _loader,
        builder: (context, state) => switch (state) {
          RiveLoaded() => _loaded(state.controller),
          RiveLoading() => const SizedBox.shrink(),
          RiveFailed() => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _loaded(RiveWidgetController controller) {
    _controller = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fire(ref.read(animationDirectorProvider));
    });
    return RiveWidget(controller: controller, fit: Fit.contain);
  }

  void _fire(AnimationPresentationState animation) {
    if (_firedSequence == animation.sequence) return;
    _firedSequence = animation.sequence;
    // This bundled asset exposes state-machine triggers, not a view model.
    // ignore: deprecated_member_use
    _controller?.stateMachine.trigger(animation.riveTrigger)?.fire();
  }
}
