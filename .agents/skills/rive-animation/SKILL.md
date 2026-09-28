---
name: toyvision-rive-animation
description: Integrate or debug Toy Vision Rive and Lottie rewards as domain-event-driven, reduced-motion-aware, failure-tolerant presentation feedback.
---

# PURPOSE

Make vector feedback reflect cleanup domain events without becoming a second
game-state owner.

# WHEN TO USE

Use for `rewards.riv`, Lottie effects, triggers/state machines, event mapping,
asset loading, fallbacks, or animation performance.

# INPUTS

- `CleanupEvent` → `AnimationPresentationState` mapping.
- Rive artboard/state-machine/input names or Lottie composition metadata.
- Reduced-motion policy, fallback UI, asset license/attribution, device target.

# PROCEDURE

1. Verify the source event and sequence in `AnimationDirector`.
2. Inspect actual asset names/inputs and bundled path; never guess a trigger.
3. Map event to one idempotent presentation transition and reset behavior.
4. Preserve a static/fallback reward and reduced-motion behavior.
5. Test repeated events, disposal/navigation, missing/corrupt assets, and no
   event case.
6. Measure jank/memory on device for release-facing changes.

# TOOLS

`AnimationDirector`, `RiveRewardEffect`, `DomainLottieEffect`, asset-integrity
tests, Flutter logs/profile, and physical-device validation.

# EXPECTED OUTPUT

Event/trigger table, verified asset contract, implementation, fallback and
reduced-motion evidence, test/profile results.

# FAILURE CONDITIONS

Fail if detection callbacks trigger rewards, asset state decides domain truth,
an absent trigger silently succeeds, or attribution/licensing is unknown.

# QUALITY GATES

Domain-event coordinator and asset-integrity tests, child flow, reduced-motion
fallback, static gates, and target-device animation/audio verification.
