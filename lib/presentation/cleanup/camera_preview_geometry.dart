import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/toy/normalized_box.dart';

/// Maps detector coordinates onto the camera preview shown by [YOLOView].
///
/// Boxes must be expressed in the same coordinate space as the analyzed source
/// pixels. Live YOLO frames are oriented before analysis; raw landscape replay
/// frames still use the clockwise quarter-turn handled here.
class CameraPreviewGeometry {
  CameraPreviewGeometry._({
    required this.viewport,
    required this.renderedWidth,
    required this.renderedHeight,
    required this.offsetX,
    required this.offsetY,
    required this.rotatesClockwise,
  });

  factory CameraPreviewGeometry({
    required Size viewport,
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final rotatesClockwise =
        viewport.height > viewport.width && sourceWidth > sourceHeight;
    final orientedWidth =
        rotatesClockwise ? sourceHeight.toDouble() : sourceWidth.toDouble();
    final orientedHeight =
        rotatesClockwise ? sourceWidth.toDouble() : sourceHeight.toDouble();
    final scale = math.max(
      viewport.width / orientedWidth,
      viewport.height / orientedHeight,
    );
    final renderedWidth = orientedWidth * scale;
    final renderedHeight = orientedHeight * scale;
    return CameraPreviewGeometry._(
      viewport: viewport,
      renderedWidth: renderedWidth,
      renderedHeight: renderedHeight,
      offsetX: (viewport.width - renderedWidth) / 2,
      offsetY: (viewport.height - renderedHeight) / 2,
      rotatesClockwise: rotatesClockwise,
    );
  }

  final Size viewport;
  final double renderedWidth;
  final double renderedHeight;
  final double offsetX;
  final double offsetY;
  final bool rotatesClockwise;

  Rect map(NormalizedBox sourceBox) {
    final box = rotatesClockwise
        ? NormalizedBox(
            x: 1 - sourceBox.bottom,
            y: sourceBox.x,
            width: sourceBox.height,
            height: sourceBox.width,
          ).clamp()
        : sourceBox.clamp();
    return Rect.fromLTWH(
      offsetX + box.x * renderedWidth,
      offsetY + box.y * renderedHeight,
      box.width * renderedWidth,
      box.height * renderedHeight,
    );
  }
}
