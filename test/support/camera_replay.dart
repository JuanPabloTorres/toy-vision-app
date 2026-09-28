import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:toyvision_realtime/domain/scene/spatial_observation.dart';
import 'package:toyvision_realtime/domain/toy/normalized_box.dart';
import 'package:toyvision_realtime/perception/perception_models.dart';

class CameraReplay {
  CameraReplay({
    required this.name,
    required this.width,
    required this.height,
    required this.frames,
  });

  final String name;
  final int width;
  final int height;
  final List<ReplayFrame> frames;

  static CameraReplay load(String path) {
    final json =
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return CameraReplay(
      name: json['name']! as String,
      width: json['width']! as int,
      height: json['height']! as int,
      frames: (json['frames']! as List<dynamic>)
          .map((value) => ReplayFrame.fromJson(value! as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  CameraPerceptionFrame render(
    ReplayFrame frame, {
    required int frameId,
    required DateTime origin,
  }) {
    final image = img.Image(width: width, height: height);
    final background = frame.background;
    img.fill(
      image,
      color: img.ColorRgb8(background[0], background[1], background[2]),
    );
    final lineColor = img.ColorRgb8(
      (background[0] + 16).clamp(0, 255),
      (background[1] + 16).clamp(0, 255),
      (background[2] + 16).clamp(0, 255),
    );
    for (var x = 0; x < width; x += 24) {
      img.drawLine(
        image,
        x1: x,
        y1: 0,
        x2: x,
        y2: height - 1,
        color: lineColor,
      );
    }
    for (var y = 0; y < height; y += 24) {
      img.drawLine(
        image,
        x1: 0,
        y1: y,
        x2: width - 1,
        y2: y,
        color: lineColor,
      );
    }
    if (frame.toy) {
      final left = (frame.toyX * width).round();
      final top = (frame.toyY * height).round();
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: (left + width * 0.2).round(),
        y2: (top + height * 0.25).round(),
        color: img.ColorRgb8(225, 32, 45),
      );
      img.drawCircle(
        image,
        x: left + 18,
        y: top + 16,
        radius: 7,
        color: img.ColorRgb8(255, 220, 40),
      );
    }
    final toyBounds = NormalizedBox(
      x: frame.toyX,
      y: frame.toyY,
      width: 0.2,
      height: 0.25,
    );
    return CameraPerceptionFrame(
      frameId: frameId,
      timestamp: origin.add(Duration(milliseconds: frame.milliseconds)),
      encodedImage: img.encodeJpg(image, quality: 92),
      detectorProposals: frame.detect
          ? [
              DetectorProposal(
                bounds: toyBounds,
                confidence: 0.86,
                knownClass: 'arbitrary-model-label',
              ),
            ]
          : const [],
      nativeInferenceMs: 32,
      nativeFps: 8,
      spatial: frame.gyroscopeRadPerSecond == null
          ? const SpatialObservation.unavailable()
          : SpatialObservation(
              timestamp: origin.add(Duration(milliseconds: frame.milliseconds)),
              motionAvailable: true,
              orientationAvailable:
                  frame.yawDegrees != null && frame.pitchDegrees != null,
              gyroscopeRadPerSecond: frame.gyroscopeRadPerSecond!,
              linearAccelerationMetersPerSecond2:
                  frame.linearAccelerationMetersPerSecond2,
              yawDegrees: frame.yawDegrees,
              pitchDegrees: frame.pitchDegrees,
            ),
    );
  }
}

class ReplayFrame {
  const ReplayFrame({
    required this.milliseconds,
    required this.background,
    required this.toy,
    required this.detect,
    this.toyX = 0.2,
    this.toyY = 0.3,
    this.gyroscopeRadPerSecond,
    this.linearAccelerationMetersPerSecond2 = 0,
    this.yawDegrees,
    this.pitchDegrees,
  });

  factory ReplayFrame.fromJson(Map<String, dynamic> json) => ReplayFrame(
        milliseconds: json['ms']! as int,
        background: (json['background']! as List<dynamic>)
            .cast<int>()
            .toList(growable: false),
        toy: json['toy']! as bool,
        detect: json['detect']! as bool,
        toyX: (json['toyX'] as num?)?.toDouble() ?? 0.2,
        toyY: (json['toyY'] as num?)?.toDouble() ?? 0.3,
        gyroscopeRadPerSecond:
            (json['gyroscopeRadPerSecond'] as num?)?.toDouble(),
        linearAccelerationMetersPerSecond2:
            (json['linearAccelerationMetersPerSecond2'] as num?)?.toDouble() ??
                0,
        yawDegrees: (json['yawDegrees'] as num?)?.toDouble(),
        pitchDegrees: (json['pitchDegrees'] as num?)?.toDouble(),
      );

  final int milliseconds;
  final List<int> background;
  final bool toy;
  final bool detect;
  final double toyX;
  final double toyY;
  final double? gyroscopeRadPerSecond;
  final double linearAccelerationMetersPerSecond2;
  final double? yawDegrees;
  final double? pitchDegrees;
}
