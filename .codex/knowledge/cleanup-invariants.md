# Cleanup invariants

```text
Proposal != Toy
Candidate != ConfirmedToy
Missing != Collected
Occluded != Collected
LostTrack != Collected
SceneChanged != Collected
0 confirmed toys != CleanupCompleted
```

Collection requires all of these current checks:

- identity belongs to the non-empty initial `RoomSnapshot`;
- confirmed toy and stable observation history;
- sufficient missing frame and wall-clock windows;
- stable scene window and similarity to the stable anchor;
- original region reobserved with meaningful local visual change;
- recent physical interaction evidence;
- no plausible occlusion;
- no plausible reidentification candidate;
- total disappearance confidence reaches the safety gate;
- not already collected by session or collected-object memory.

Completion requires every snapshot identity collected, verified non-zero
progress, no remaining stable snapshot toy, no unresolved initial track, no new
stable confirmed toy, no persistent detector candidate, a stable clean window,
and final-room coverage across distinct viewpoints. An empty snapshot returns
insufficient. Only `RoomCleanVerifier.clean` may lead the application service
to publish `RoomCleanConfirmed` and then `CleanupCompleted`.

Production event-origin audit:

```powershell
rg -n 'ToyCollected\(' lib
rg -n 'CleanupCompleted\(' lib
```

Apart from declarations/serialization matches, construction must remain in
`lib/application/cleanup/cleanup_session_service.dart`.
