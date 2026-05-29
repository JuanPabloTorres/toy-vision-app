/// Lifecycle status of the camera, surfaced to the UI to pick the right view.
enum CameraStatus {
  initializing,
  permissionDenied,
  ready,
  error,
}
