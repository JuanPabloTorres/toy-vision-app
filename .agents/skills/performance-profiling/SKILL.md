---
name: toyvision-performance-profiling
description: Profile Toy Vision frame latency, drops, FPS, isolates/rebuilds, memory, thermal, battery, delegates, and APK behavior with environment-specific evidence.
---

# PURPOSE

Locate a measured bottleneck without weakening perception correctness or
confusing desktop replay budgets with target-device behavior.

# WHEN TO USE

Use for slow inference/UI, frame drops, high RSS, heat, battery drain, delegate
changes, scheduler changes, or release performance claims.

# INPUTS

- Exact commit/APK hash, build mode/flags, model/delegate/resolution.
- Host/device model and OS, scenario/duration, thermal/battery start state.
- Native inference, analysis/fusion/tracking, wall latency, drops, RSS, CPU/GPU,
  frame timing, thermal and battery traces.

# PROCEDURE

1. Establish a fixed scenario and cold/warm baseline.
2. Label every metric `desktop` or exact physical device.
3. Separate native YOLO, Dart analysis, fusion/tracking, UI/render, and I/O.
4. Find the dominant p95/drop/memory/thermal contributor.
5. Change one owner/policy at a time; preserve safety and replay outputs.
6. Re-run same scenario and compare distributions, not a single average.
7. Run sustained device monitoring for release claims.

# TOOLS

Performance tests, `PerceptionMetrics`, Flutter DevTools/profile, ADB dumpsys
and logcat, `tools/certify_galaxy_s25.ps1`, APK hashes, and scheduler tests.

# EXPECTED OUTPUT

Reproducible environment, p50/p95/drop/RSS/thermal/battery table, bottleneck,
before/after evidence, correctness regressions, and verdict.

# FAILURE CONDITIONS

Fail if Windows numbers are extrapolated to Galaxy, debug-mode timings are
release evidence, scenarios differ before/after, or FPS gains weaken collection
gates.

# QUALITY GATES

Desktop regression budget, full correctness replay, scheduler thermal tests,
target-device sustained profile, no false collection, and static/full tests.
