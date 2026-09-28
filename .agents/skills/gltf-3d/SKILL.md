---
name: toyvision-gltf-3d
description: Integrate, validate, or optimize Tobi glTF/GLB assets, animation clips, state transitions, fallback rendering, and mobile performance.
---

# PURPOSE

Keep Tobi's 3D presentation reproducible, event-driven, and safe on unsupported
or resource-constrained devices.

# WHEN TO USE

Use for `tobi.gltf`, GLB conversion, rigs/clips, `flutter_3d_controller`,
animation names, fallback mascot, or 3D performance.

# INPUTS

- Asset path/hash, glTF JSON/buffers/textures, animation/rig names.
- `AnimationPresentationState.modelAnimation` mapping.
- Target device, load/render errors, memory/frame profile, fallback behavior.

# PROCEDURE

1. Validate glTF structure, referenced resources, animation names, and license.
2. Compare every domain presentation state with an existing clip.
3. Verify load/dispose/navigation and unsupported-platform behavior.
4. Preserve `TobiMascot` fallback and a complete child flow without 3D.
5. Use `tools/generate_tobi_gltf.dart` when regenerating the repository asset;
   record the resulting hash/diff.
6. Profile load time, RSS, frame timing, thermal impact on target Android.

# TOOLS

`tools/generate_tobi_gltf.dart`, asset-integrity test, `Tobi3dStage`, Flutter
logs/profile, SHA-256, and Galaxy certification.

# EXPECTED OUTPUT

Asset/clip contract, generation provenance, event mapping, fallback results,
tests, and device performance evidence.

# FAILURE CONDITIONS

Fail if animation reacts to detector output, missing clips are hidden, the game
cannot continue without 3D, external assets lack licensing, or desktop render
is claimed as Android proof.

# QUALITY GATES

Asset integrity, event mapping, fallback child flow, static/full tests,
commercial asset review, and target-device 3D profile.
