import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/models/bounding_box.dart';
import 'package:toyvision_realtime/tracking/iou_calculator.dart';

void main() {
  const iou = IoUCalculator();

  test('identical boxes have IoU of 1.0', () {
    const box = BoundingBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2);
    expect(iou.iou(box, box), closeTo(1.0, 1e-9));
  });

  test('non-overlapping boxes have IoU of 0', () {
    const a = BoundingBox(x: 0.0, y: 0.0, width: 0.2, height: 0.2);
    const b = BoundingBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2);
    expect(iou.iou(a, b), 0);
  });

  test('partial overlap computes the correct ratio', () {
    // A and B each 0.04 area; intersection 0.02; union 0.06 -> 1/3.
    const a = BoundingBox(x: 0.0, y: 0.0, width: 0.2, height: 0.2);
    const b = BoundingBox(x: 0.1, y: 0.0, width: 0.2, height: 0.2);
    expect(iou.iou(a, b), closeTo(1 / 3, 1e-9));
  });

  test('IoU is symmetric', () {
    const a = BoundingBox(x: 0.0, y: 0.0, width: 0.3, height: 0.2);
    const b = BoundingBox(x: 0.15, y: 0.05, width: 0.3, height: 0.2);
    expect(iou.iou(a, b), closeTo(iou.iou(b, a), 1e-12));
  });
}
