# Lottie animations — Toy Cleanup YOLO

Drop animated `.json` files in this directory and the app will load them
automatically. `LottieStatusView` falls back to a static Material icon when
a referenced file is missing, so the app stays functional with an empty
directory — but Mateo's experience gets noticeably better once you provide
each one.

## Expected file names

| File | Where it appears | Free sources |
|------|------------------|--------------|
| `mission_loading.json` | While YOLO downloads / loads the model. | "robot loading", "loading spinner" on lottiefiles.com |
| `toy_scan.json` | While the controller captures the initial toy count (~3 s). | "radar scan", "magnifier search" |
| `mission_complete.json` | When the visible-toy count first reaches 0 after a mission has begun. | "confetti celebration", "trophy" |
| `success_star.json` | Brief pop when Mateo picks up one toy (count goes down). | "star pop", "checkmark" |
| `permission_camera.json` | Camera-permission view. | "camera permission", "phone access" |

## Sizing & duration

- Square aspect (~256×256) renders best inside the panels.
- Loop animations should be ≤2 s so they don't distract.
- Celebration (mission_complete) can be longer (~3 s) but should auto-stop.

## License

Use Lottie files licensed for redistribution (CC0 / MIT / "free for
personal use"). Keep author credit in this README when adding files.

## How the fallback works

`LottieStatusView` accepts an optional `assetPath`. If the asset is
missing, it shows the `fallbackIcon` (a Material icon) animated with a
gentle scale tween. This keeps the app visually consistent during
development without forcing a Lottie file to exist.
