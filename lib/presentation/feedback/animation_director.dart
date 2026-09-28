import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cleanup/cleanup_event.dart';

enum TobiState {
  idle,
  searching,
  foundToy,
  encouraging,
  celebrating,
  confused,
  finished,
}

class AnimationPresentationState {
  const AnimationPresentationState({
    this.tobiState = TobiState.idle,
    this.riveTrigger = 'idle',
    this.modelAnimation = 'idle',
    this.lottieEffect,
    this.sequence = 0,
  });

  final TobiState tobiState;
  final String riveTrigger;
  final String modelAnimation;
  final String? lottieEffect;
  final int sequence;
}

class AnimationDirector extends Notifier<AnimationPresentationState> {
  Timer? _resetTimer;

  @override
  AnimationPresentationState build() {
    ref.onDispose(() => _resetTimer?.cancel());
    return const AnimationPresentationState();
  }

  void handle(CleanupEvent event) {
    _resetTimer?.cancel();
    if (event is CleanupStarted) {
      searching();
    } else if (event is NewToyDiscovered) {
      searching();
    } else if (event is ToyCollected) {
      state = AnimationPresentationState(
        tobiState: TobiState.foundToy,
        riveTrigger: 'star_burst',
        modelAnimation: 'clap',
        lottieEffect: 'assets/lottie/toy_collected.json',
        sequence: state.sequence + 1,
      );
      _scheduleReset(TobiState.encouraging);
    } else if (event is RoomAlmostClean) {
      state = AnimationPresentationState(
        tobiState: TobiState.encouraging,
        riveTrigger: 'almost_finished',
        modelAnimation: 'happy',
        sequence: state.sequence + 1,
      );
      _scheduleReset(TobiState.searching);
    } else if (event is EmptyRoomVerificationStarted) {
      searching();
    } else if (event is CleanupCompleted) {
      state = AnimationPresentationState(
        tobiState: TobiState.finished,
        riveTrigger: 'celebrate',
        modelAnimation: 'celebrate',
        lottieEffect: 'assets/lottie/celebration.json',
        sequence: state.sequence + 1,
      );
    } else if (event is PerceptionUncertain) {
      state = AnimationPresentationState(
        tobiState: TobiState.confused,
        riveTrigger: 'confused',
        modelAnimation: 'confused',
        sequence: state.sequence + 1,
      );
      _scheduleReset(TobiState.searching);
    }
  }

  void searching() {
    state = AnimationPresentationState(
      tobiState: TobiState.searching,
      riveTrigger: 'searching',
      modelAnimation: 'scan',
      sequence: state.sequence + 1,
    );
  }

  void _scheduleReset(TobiState target) {
    _resetTimer = Timer(const Duration(milliseconds: 1200), () {
      state = AnimationPresentationState(
        tobiState: target,
        riveTrigger: target == TobiState.searching ? 'searching' : 'idle',
        modelAnimation: target == TobiState.searching ? 'scan' : 'idle',
        sequence: state.sequence + 1,
      );
    });
  }
}

final animationDirectorProvider =
    NotifierProvider<AnimationDirector, AnimationPresentationState>(
  AnimationDirector.new,
);
