/// Lifecycle status of the camera, surfaced to the UI to pick the right view
/// and to explain failures specifically rather than collapsing them into one
/// generic error.
enum CameraStatus {
  initial,
  initializing,
  permissionDenied,
  permissionPermanentlyDenied,
  ready,
  streaming,
  paused,
  error,
  disposed,
}
