# Sensor fusion and room verification

## Implemented path

Every live YOLO frame can carry a `SpatialObservation` sampled from Android's
gyroscope, linear acceleration sensor and game rotation vector. These signals
do not decide gameplay directly.

```text
YOLO + visual crops + tracking
             │
IMU + rotation vector ─→ SceneStabilityService
             │                    │
             └──────────→ SensorFusionEngine
                                  │
                    ToyRemovalVerifier
                                  │
                    RoomCoverageTracker
                                  │
                     RoomCleanVerifier
```

`ToyRemovalVerifier` still requires a confirmed initial-snapshot identity, a
sustained missing window, reobservation of its prior region, no occlusion, no
plausible reidentification and recent interaction evidence. IMU movement can
only block confirmation. Background reveal or optional depth is corroborating
evidence; absence alone remains insufficient.

`RoomCoverageTracker` uses relative yaw/pitch to record left, center, right and
floor sectors. If orientation is absent it falls back to distinct visual scene
viewpoints, so unsupported devices remain functional. `RoomCleanVerifier`
returns one of `toyFound`, `needMoreCoverage` or `roomClean`, with a guidance
string and explicit blockers.

## Optional AR pose and depth contract

`SpatialObservation` includes optional pose/depth capability fields. They are
not populated by the current CameraX camera owner. This is intentional:

- ARCore Shared Camera requires the application to own a Camera2 session and
  wrap its callbacks and surfaces.
- The current `ultralytics_yolo` Flutter surface owns CameraX internally.
- ARCore states that hardware depth is unavailable while Shared Camera is
  active.

Consequently a real ARCore provider requires replacing the camera owner with a
native Camera2/ARCore Shared Camera pipeline that also feeds TFLite inference.
Starting a second ARCore session beside the current camera would be unsafe and
is not treated as implemented sensor evidence.

Primary references:

- https://developer.android.com/develop/sensors-and-location/sensors/sensors_motion
- https://developers.google.com/ar/develop/java/camera-sharing
- https://developers.google.com/ar/reference/java/com/google/ar/core/SharedCamera
- https://developers.google.com/ar/develop/java/depth/developer-guide
