# Quality gates

Apply only gates relevant to the change, but a release verdict must evaluate
all rows. Record command, timestamp, environment, artifact/hash when relevant,
result, and evidence path.

| Gate | Required evidence | PASS condition |
|---|---|---|
| Architecture | import/owner audit plus `ToyCollected` origin search | no new inversion or duplicate owner |
| Static | `dart format --output=none --set-exit-if-changed lib test tools` and `flutter analyze` | both exit 0, analyzer has 0 issues |
| Unit/component | focused tests, then `flutter test -r expanded` | all applicable tests pass |
| Replay | integration replays and original failure trace | expected event/identity sequence, no regression |
| Adversarial | scenario matrix in `knowledge/testing-scenarios.md` | every applicable row PASS or explicitly blocked |
| Perception | representative annotated corpus through certification harness | acceptance thresholds pass, zero forbidden collection failures |
| Gameplay | Home→Scan→Cleanup→Celebration observable flow | child can finish without debug UI/dead end |
| Performance | desktop regression plus physical device profile | budgets pass in the environment claimed |
| Device | `tools/certify_galaxy_s25.ps1` on supported physical device | complete retained evidence and manual checks |
| Privacy | manifest/storage/capture-mode review | no silent sensitive retention/upload |
| Commercial | dependency/model/assets license and release-signing review | all distribution rights and signing resolved |
| Independent release | `release_auditor` reviews evidence it did not implement | explicit PASS with no blocker |

## Useful commands

```powershell
C:\DevTools\flutter\bin\flutter.bat pub get
C:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test tools
C:\DevTools\flutter\bin\flutter.bat analyze
C:\DevTools\flutter\bin\flutter.bat test -r expanded
C:\DevTools\flutter\bin\flutter.bat test test/integration -r expanded
C:\DevTools\flutter\bin\flutter.bat test test/performance -r expanded
C:\DevTools\flutter\bin\flutter.bat pub run tools/toyvision_certify.dart validate certification/dataset.json
C:\DevTools\flutter\bin\flutter.bat pub run tools/toyvision_certify.dart evaluate certification/dataset.json certification/results/final-test
.\tools\certify_galaxy_s25.ps1 -IUnderstandFramesAreStored -UseGpu -MonitorSeconds 900
```

The sample dataset is intentionally incomplete and must produce `BLOCKED`, not
PASS. The Galaxy script is interactive and physically destructive only to the
test app installation/capture area; run it only with explicit operator consent.

## Absolute blockers

- Any false collection or duplicate collection above the accepted corpus limit.
- `CleanupCompleted` with an empty snapshot or zero verified progress.
- A claim about Galaxy/device behavior without device evidence.
- A closed-commercial claim while Ultralytics licensing remains unresolved.
- Release build signed with debug keys.
- Missing/incomplete corpus presented as evaluated PASS.

Compilation, APK generation, unit tests, or clean architecture alone are never
sufficient for release PASS.
