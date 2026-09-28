# Testing scenarios

Report each row as `PASS`, `FAIL`, `NOT_EXECUTED`, or `BLOCKED_DEVICE`.

| Scenario | Critical assertions |
|---|---|
| stationary camera | stable snapshot; no spontaneous progress |
| slow/fast pan, rotation | no collection during movement |
| camera shake | no verified disappearance/completion |
| camera covered/uncovered | obscured; recover without progress |
| low light / motion blur | uncertainty, no fabricated progress |
| person crosses camera | no toy confirmation/collection from person |
| hand/basket occlusion | occlusion blocks collection |
| true toy pickup in stable view | exactly one correct `ToyCollected` |
| toy disappears then reappears | same identity, zero collection before return |
| same/collected-looking toy twice | no duplicate collection |
| multiple overlapping/similar toys | bounded ID switches, correct identities |
| clothing, shoes, remote, bottle, box, furniture, empty floor | no confirmed toy/collection |
| unknown toy | candidate behavior measured; no unsupported semantics |
| tiny/large/low-contrast/partial toy | expected recall without unsafe FP |
| complete room | exactly one completion after verified progress |
| zero/empty initial snapshot | never completes |
| permission deny/retry, model failure | recoverable UI, no dead end |
| background/resume/repeated session | safe lifecycle and fresh identity/session |
| low battery / serious-critical thermal | scheduler adapts; correctness preserved |
| Rive/Lottie/glTF/audio/haptics/mute/fallback | event-driven, usable fallback |

The certification corpus additionally requires independent train/validation/test
captures tagged with known/unknown/stuffed/vehicle/figure/blocks/small,
occlusion, multiple, low-light, blur, interaction, camera motion,
disappear/reappear, and hard negatives. Default thresholds are precision ≥ .90,
recall ≥ .85, F1 ≥ .87, identity AUC ≥ .90, toy/non-toy AUC ≥ .85, with zero
ID switches, duplicate collections, and false collections.
