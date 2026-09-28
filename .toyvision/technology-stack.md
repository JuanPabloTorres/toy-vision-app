# Technology Stack

- Flutter / Dart / Material 3
- Riverpod for immutable state and dependency injection
- `ultralytics_yolo` for on-device camera inference
- TFLite model asset with configured fallback model
- SharedPreferences-backed privacy-safe settings and cleanup-session history
- `audioplayers` and Lottie with reduced-motion fallbacks

The production camera path is `YOLOView → mapping → validation → tracking →
RoomSnapshotBuilder → KidGameController`. There is no backend dependency in the
live loop and no normal Kid Mode detection overlay.
