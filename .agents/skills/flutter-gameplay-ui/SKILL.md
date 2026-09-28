---
name: toyvision-flutter-gameplay-ui
description: Design, implement, or audit Toy Vision's Flutter child game loop, Riverpod state rendering, camera overlays, accessibility, lifecycle, and rebuild performance.
---

# PURPOSE

Keep the product a simple cleanup game while implementing responsive,
accessible Flutter UI that does not own perception truth.

# WHEN TO USE

Use for Home/Scan/Cleanup/Celebration, HUD, Tobi, onboarding, settings/debug
separation, layout, lifecycle, or rebuild issues.

# INPUTS

- Target child outcome and `CleanupState`/event transitions.
- Viewports, text scale, accessibility/reduced-motion needs.
- Current widget/provider tree, camera lifecycle, and performance evidence.

# PROCEDURE

1. Walk the real flow and record action, feedback, exit, and dead-end at each
   state.
2. Map each visual change to application state or a domain event; reject direct
   detector-driven rewards.
3. Keep Kid Mode free of boxes/labels/confidence/IDs; keep developer overlay
   explicitly gated.
4. Implement the smallest compositional change using existing tokens/components.
5. Check camera init/dispose/background/error/retry and Riverpod subscription
   lifetimes.
6. Test small screens, text scaling, touch targets, reduced motion, failures,
   and Home→Cleanup→Celebration.
7. Profile rebuilds/frame timing when per-frame state is affected.

# TOOLS

Flutter widget tests, analyzer, DevTools/profile mode, target device,
`test/presentation/home_flow_test.dart`, and existing UI/theme components.

# EXPECTED OUTPUT

Flow/state map, implementation, accessibility/responsive evidence, tests,
performance impact, and device-only gaps.

# FAILURE CONDITIONS

Fail if UI constructs domain collection/completion, Kid Mode leaks debug data,
the next action is unclear, or a camera lifecycle/dead-end remains untested.

# QUALITY GATES

Static/widget/full tests; child-flow manual or automated evidence; no overflow
at target sizes; debug separation; performance/device gates when camera UI
changes.
