# Responsive visual shell — physical-device evidence

Validated on 2026-09-27 with a Samsung Galaxy S25 (`SM-S942U`, ADB serial
`RFGL31RLP8W`). The release APK was installed with `adb install -r` and all four
primary destinations were opened through the production bottom navigation.

| Destination | Screenshot |
|---|---|
| Home | `device-evidence/ui-shell-home-galaxy-s25.png` |
| Progress | `device-evidence/ui-shell-progress-galaxy-s25.png` |
| Settings | `device-evidence/ui-shell-settings-galaxy-s25.png` |
| About | `device-evidence/ui-shell-about-galaxy-s25.png` |

Release APK SHA-256:
`F702BD37204224380CE980822F5E3FF373F72E4420D14BF74A46C334B354BF20`.

Validation result:

- `flutter analyze`: no issues.
- `flutter test`: 65 tests passed.
- `flutter build apk --release`: success, 178.1 MB.
- Android runtime log after cold launch: no fatal entries.
- Responsive widget coverage includes 320×568 logical pixels with 1.3× text.

This evidence certifies the visual shell and navigation only. It does not
replace real-camera perception or labeled-corpus acceptance evidence.
