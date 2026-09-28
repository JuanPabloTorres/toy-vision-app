# Project Operating System

## Product goal

A preschool child taps **¡Jugar!**, leaves the phone aimed at the play area,
cleans supported toys in any order, sees Tobi gain energy, and finishes through
a reinforced visual check plus simple human confirmation.

Computer vision assists the game. It does not claim perfect knowledge of the
physical room.

## Rules

- One primary flow and one authoritative `KidGamePhase` owner.
- No required selected object, child-facing detector ceremony, or competing counters.
- No progress from a single frame and no completion from a single zero observation.
- Visible energy is monotonic and distinct from detector estimates.
- No images/video are saved or uploaded by default.
- No face/person identification.
- Business logic remains outside widgets and model adapters.
- Current behavior is protected by domain, controller, storage, and UI tests.

## Definition of done

A change is done only when architecture ownership is unambiguous, privacy and
real-time performance remain intact, tests cover changed behavior,
`flutter analyze` has zero issues, and the current test suite passes.
