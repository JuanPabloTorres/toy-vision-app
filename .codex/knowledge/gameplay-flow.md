# Gameplay flow

```text
Home: one dominant ¡Jugar! action
→ CameraGameScreen / Ready: camera already open; one Estoy listo action
→ Discovering: coverage + movement + stable toys + quiet window establish the snapshot
→ Cleaning: one visible stable target; pickup → verified domain event → reward
→ Verifying removal: disappearance is checked without incrementing progress
→ Verifying room: zero remaining starts a final inspection, never completion by itself
→ Completed: celebration only after strong sustained empty-room evidence
→ Finish/Home
```

The camera surface remains mounted across Ready, Discovering, Cleaning,
Verifying removal, and Verifying room. Discovery transitions automatically to
Cleaning; there is no scan-results page or second start button.

`RoomDiscoverySession` owns discovery completion evidence. `TargetSelector`
chooses only a confirmed visible target. A stable toy found after the initial
snapshot enters the room inventory through `NewToyDiscovered` before it can be
collected. `ToyRemovalVerifier` proves a specific removal; `RoomCleanVerifier`
accumulates final-room coverage and a sustained clean window. Both return
decisions/evidence only. `CleanupSessionService` remains the sole production
owner of `ToyCollected`, `RoomCleanConfirmed`, and `CleanupCompleted`.

`VisionStatus` (`stopped`, `initializing`, `running`, `error`) is independent
from `CleanupPhase`. Perception may remain `running` while the game moves from
Cleaning to Verifying removal and Verifying room; discovery mode only tunes
the perception strategy and never represents gameplay state.

The game should continually answer for a child: “What do I do now?”, “Did the
system notice?”, and “What happens next?” Technical uncertainty must become a
friendly wait/retry state, never fabricated progress.

Kid Mode shows halos/encouragement/progress without detector labels,
confidence, track IDs, or raw diagnostics. Developer Vision Debug is a separate
setting and may show YOLO/open-set/candidate/track/missing evidence.

`AnimationDirector` maps `CleanupStarted`, `ToyCollected`, `RoomAlmostClean`,
`CleanupCompleted`, and `PerceptionUncertain` to Tobi/Rive/Lottie states.
`CleanupFeedbackCoordinator` maps the same events to audio/haptics. These are
consumers; neither may create domain facts.
