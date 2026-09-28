import '../perception_models.dart';

abstract interface class ObjectDetector {
  Future<List<DetectorProposal>> detect(CameraPerceptionFrame frame);
}

/// The native CameraX/TFLite view already ran YOLO before emitting a frame.
/// This adapter makes that detector an explicit pipeline dependency.
class NativeProposalObjectDetector implements ObjectDetector {
  const NativeProposalObjectDetector();

  @override
  Future<List<DetectorProposal>> detect(CameraPerceptionFrame frame) async =>
      frame.detectorProposals;
}
