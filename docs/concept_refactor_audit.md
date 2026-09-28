# Toy Vision concept-to-product audit

Date: 2026-09-27

Source of product truth: the ten screens in `docs/App-Concepts-Images` and the
attached Toy Vision product specification. This audit covers the refactor that
maps those concepts onto the existing layered implementation without moving
perception decisions into Flutter widgets.

## Component classification

| Area | Decision | Result |
|---|---|---|
| Hybrid perception, tracking and disappearance pipeline | KEEP | The existing typed pipeline and `ObjectDetector`/`EmbeddingExtractor` boundaries remain the only source of visual evidence. |
| `CleanupSessionService` | REFACTOR | Added sustained empty-room verification before completion; it remains the sole production owner of `ToyCollected` and `CleanupCompleted`. |
| `CleanupController` | REFACTOR | Its phase model now matches preparing → scanning → confirming room → cleaning → verifying empty → celebration. It coordinates but does not classify pixels. |
| Camera screen | REFACTOR | One route owns scanning, confirmation, gameplay and empty verification. The camera remains mounted from scan through verification. |
| Home | REFACTOR | Replaced the demo landing page with Tobi, one primary action, persisted progress, last-session summary, Settings and About. |
| Splash and camera onboarding | ADD | First-run path explains local processing before requesting the real Android camera permission. |
| Settings and About | REFACTOR / ADD | Persisted feedback/animation/kid-mode controls, isolated developer diagnostics, privacy/model/license information. |
| Mission/challenge/review/target-selection flows | DELETE | These legacy components remain removed and are not reintroduced. |
| Design system | REFACTOR | Shared background, wordmark, card, speech bubble, header, icon action and primary CTA are reused across screens. |
| Category labels in child UI | DELETE | Detector labels remain diagnostics only. The child sees a visual target and stable count, never model confidence or label-driven truth. |

## Product flow implemented

`Splash → camera onboarding (first run) → Home → Prepare → Scan → Confirm room → Cleanup → Verify empty → Celebration → Home`

The visual concepts show category names and a phrase such as “Busca el
carrito”. The production architecture cannot safely promise that semantic name
for an open-set object. The equivalent child-facing interaction is “Busca el
juguete brillante”, with exactly one track highlighted and all other confirmed
tracks rendered softly. This preserves the visual hierarchy without converting
a diagnostic YOLO label into domain truth.

## State ownership

- Perception owns proposals, embeddings, fusion, tracks, scene stability and
  disappearance evidence.
- `CleanupSessionService` freezes `RoomSnapshot`, accepts verified collections,
  prevents duplicate progress and performs the second empty-room verification.
- `CleanupController` exposes application phase and immutable state to the UI.
- Presentation renders state and sends explicit user intents (`beginScan`,
  `beginCleanup`, `rescanRoom`); it never creates collection events.
- Domain events drive audio, haptics, Lottie and Tobi state. The Rive adapter is
  isolated but disabled until a Toy Vision production asset replaces the
  generic game HUD exposed by physical review.
- Completed session summaries back Home progress through
  `CleanupHistoryRepository`; no camera frames are stored for this purpose.

## Deliberate constraints

- The polished 2D Tobi asset is used in the child flow. The bundled glTF
  integration remains event-capable, but its current primitive model is not
  rendered in production screens because physical review showed it regressed
  the visual quality. A production glTF can replace the adapter input later
  without changing cleanup state or domain events. The concept images define
  composition and emotional role; they are not copied into the bundle as
  screenshots.
- The bundled `rewards.riv` rendered an unrelated chest/coins HUD on the real
  device and is not mounted in production screens. This prevents a known
  visual regression without coupling domain events to an asset format.
- Developer diagnostics require disabling kid mode first and never share the
  child-facing overlay.
- Physical accuracy and release certification remain governed by the real
  device/corpus evidence documents; visual completion is not evidence that the
  detector meets acceptance quality.

## Applied child-interface instruction

The visual instruction supplied on 2026-09-27 is implemented as presentation
behavior, not as new perception logic:

| Instruction | Production behavior | Evidence |
|---|---|---|
| Friendly identification boxes | Rounded corner brackets, translucent fill and soft glow replace generic detector rectangles. | `ToyHaloLayer` custom painter |
| Candidate → confirmed → active | Confirmed-but-not-stable evidence is cyan; a stable track is green with a check; the selected target expands and pulses in yellow with a star. | `ToyTrack` state projected by `ToyHaloLayer` |
| Collected feedback | Spark/celebration Lottie, sound and haptic feedback continue to be triggered by the `ToyCollected` domain event. | `CleanupFeedbackCoordinator` and `AnimationDirector` |
| Reactive Tobi | The 2D production mascot maps idle, search, found, encourage, celebrate and confused states to distinct friendly motions; the 3D adapter receives the same state. | `AnimationDirector`, `Tobi3dStage`, `TobiMascot` |
| Living controls | The shared primary action uses 200 ms press feedback and an optional gentle breathing loop. | `PrimaryActionButton`, `AppDurations.fast` |
| Cards and counters | Collection progress now changes with a 250 ms scale/fade transition. | `_ProgressPill` |
| Motion accessibility | Halo loops and Lottie effects stop when app animations are disabled or the operating system requests reduced motion. | `ToyHaloLayer`, `DomainLottieEffect` |
| No technical language | Child mode exposes neither labels, confidence, track IDs nor generic YOLO boxes. | Widget test and separate developer overlay |

The reference asks for a friendly label per toy. That literal behavior is not
implemented because an open-set track may not have a truthful semantic name.
Showing YOLO's best label would violate the product architecture and could
mislead the child. The equivalent production cue is the highlighted object plus
the short instruction “Busca el juguete brillante”.

## Original asset pack

Thirty-four icons are now original Toy Vision assets rather than a mix of
generic libraries. The catalog covers GAME, SYSTEM, PROGRESS and VISION,
including the proposed 25-icon core plus progress, information, settings and
trust/support variants.
They share rounded toy-plastic geometry, a fixed three-quarter camera angle,
consistent highlights and the production palette. Each source was generated
independently against the same visual reference, stored with real transparency,
and downscaled to 512 px before bundling to avoid decoding oversized artwork on
device.

Home and Celebration consume the new files through `AppAssets` and `AppImage`.
Material symbols remain accessible fallbacks, not the normal production path.
The shared primary button now supports idle, pressed, loading, success and
disabled presentation states without acquiring application or domain state.

`assets/ASSET_MANIFEST.yaml` is the admission gate for future artwork. No Rive
Marketplace, LottieFiles, Lordicon, IconScout, Poly Pizza or Sketchfab resource
was downloaded in this phase. A production `Tobi.riv` remains intentionally
deferred: it must be authored specifically for Toy Vision with the agreed state
machine rather than replaced by a generic marketplace character.
