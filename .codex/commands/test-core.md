# `test-core` recipe

Run focused tests first, then:

```powershell
C:\DevTools\flutter\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test tools
C:\DevTools\flutter\bin\flutter.bat analyze
C:\DevTools\flutter\bin\flutter.bat test test/perception test/infrastructure -r expanded
C:\DevTools\flutter\bin\flutter.bat test test/integration -r expanded
```

Report commands, exit codes, counts, and skipped/device-only coverage. Do not
translate passing core tests into real-world perception PASS.
