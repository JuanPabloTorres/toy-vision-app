import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/detection/yolo/yolo_detection_mapper.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

YOLOResult _yoloResult({
  required String className,
  double confidence = 0.8,
  Rect? normalized,
}) {
  final n = normalized ?? const Rect.fromLTWH(0.1, 0.2, 0.3, 0.4);
  return YOLOResult(
    classIndex: 0,
    className: className,
    confidence: confidence,
    boundingBox: const Rect.fromLTWH(100, 200, 300, 400),
    normalizedBox: n,
  );
}

void main() {
  const mapper = YoloDetectionMapper();

  group('YoloDetectionMapper — auto toys', () {
    test('teddy bear → stuffed_animal', () {
      final out = mapper.map([_yoloResult(className: 'teddy bear')]);
      expect(out, hasLength(1));
      expect(out.single.label, 'stuffed_animal');
    });

    test('sports ball → ball', () {
      final out = mapper.map([_yoloResult(className: 'sports ball')]);
      expect(out.single.label, 'ball');
    });

    test('is case-insensitive', () {
      final out = mapper.map([_yoloResult(className: 'TEDDY BEAR')]);
      expect(out.single.label, 'stuffed_animal');
    });
  });

  group('YoloDetectionMapper — likely-toy proxies', () {
    test('car → toy_car', () {
      final out = mapper.map([_yoloResult(className: 'car')]);
      expect(out.single.label, 'toy_car');
    });

    test('fire hydrant → unknownToy (red toy mislabelled, recovered indoors)',
        () {
      final out = mapper.map([_yoloResult(className: 'fire hydrant')]);
      expect(out.single.label, 'unknownToy');
    });

    test('truck → toy_truck', () {
      final out = mapper.map([_yoloResult(className: 'truck')]);
      expect(out.single.label, 'toy_truck');
    });

    test('train → toy_train', () {
      final out = mapper.map([_yoloResult(className: 'train')]);
      expect(out.single.label, 'toy_train');
    });

    test('airplane → toy_vehicle (a plane indoors is a toy plane)', () {
      for (final c in ['airplane', 'aeroplane']) {
        final out = mapper.map([_yoloResult(className: c)]);
        expect(out.single.label, 'toy_vehicle', reason: 'for $c');
      }
    });
  });

  group('YoloDetectionMapper — precision pass (dropped non-toys)', () {
    test('drops the still-noisy vehicle proxies', () {
      for (final c in ['boat', 'bicycle', 'motorcycle', 'bus']) {
        final out = mapper.map([_yoloResult(className: c)]);
        expect(out, isEmpty, reason: 'for $c');
      }
    });

    test('drops kite / frisbee / skateboard (rarely the kid\'s toy)', () {
      for (final c in ['kite', 'frisbee', 'skateboard']) {
        final out = mapper.map([_yoloResult(className: c)]);
        expect(out, isEmpty, reason: 'for $c');
      }
    });

    test('drops book / backpack / suitcase / scissors (false-positive prone)',
        () {
      for (final c in ['book', 'backpack', 'suitcase', 'scissors']) {
        final out = mapper.map([_yoloResult(className: c)]);
        expect(out, isEmpty, reason: 'for $c');
      }
    });
  });

  group('YoloDetectionMapper — custom toy-model labels', () {
    test('maps the toy-model prompt strings to registry labels', () {
      const cases = {
        'teddy bear': 'stuffed_animal',
        'stuffed animal': 'stuffed_animal',
        'plush toy': 'stuffed_animal',
        'doll': 'doll',
        'toy car': 'toy_car',
        'toy truck': 'toy_truck',
        'toy train': 'toy_train',
        'building blocks': 'building_blocks',
        'lego': 'building_blocks',
        'ring stacker': 'ring_stacker',
        'stacking rings': 'ring_stacker',
        'action figure': 'action_figure',
        'puzzle': 'puzzle',
        'toy': 'unknownToy',
        'red toy': 'unknownToy',
        'blue toy': 'unknownToy',
        'small toy': 'unknownToy',
        'plastic toy': 'unknownToy',
      };
      cases.forEach((raw, expected) {
        final out = mapper.map([_yoloResult(className: raw)]);
        expect(out.single.label, expected, reason: 'for "$raw"');
      });
    });

    test('recall pass: short toy-model aliases also map (teddy/plush/toys/'
        'block/blocks)', () {
      const cases = {
        'teddy': 'stuffed_animal',
        'plush': 'stuffed_animal',
        'toys': 'unknownToy',
        'block': 'building_blocks',
        'blocks': 'building_blocks',
      };
      cases.forEach((raw, expected) {
        final out = mapper.map([_yoloResult(className: raw)]);
        expect(out.single.label, expected, reason: 'for "$raw"');
      });
    });

    test('every toyModelLabels value is a registered producedLabel', () {
      for (final label in YoloDetectionMapper.toyModelLabels.values) {
        expect(
          YoloDetectionMapper.producedLabels.contains(label),
          isTrue,
          reason: '"$label" missing from producedLabels',
        );
      }
    });
  });

  group('YoloDetectionMapper — dropped classes', () {
    test('generic object is not automatically a toy without toy-like evidence',
        () {
      final out = mapper.map([_yoloResult(className: 'object')]);
      expect(out, isEmpty);
    });

    test('drops person, chair, couch, bed, tv, laptop, cell phone', () {
      final dropped = [
        'person',
        'chair',
        'couch',
        'bed',
        'dining table',
        'tv',
        'laptop',
        'cell phone',
        'remote',
        'keyboard',
        'mouse',
        'refrigerator',
        'microwave',
        'oven',
        'sink',
        'toilet',
        'clock',
        'vase',
        'potted plant',
        'hair drier',
        'toothbrush',
      ];
      final out = mapper.map([
        for (final c in dropped) _yoloResult(className: c),
      ]);
      expect(out, isEmpty);
    });

    test('drops real animals (dog, cat, bird, horse, …)', () {
      final dropped = [
        'dog',
        'cat',
        'bird',
        'horse',
        'sheep',
        'cow',
        'elephant',
        'bear',
        'zebra',
        'giraffe',
      ];
      final out = mapper.map([
        for (final c in dropped) _yoloResult(className: c),
      ]);
      expect(out, isEmpty);
    });

    test('drops unrecognized class names instead of throwing', () {
      final out = mapper.map([
        _yoloResult(className: 'unicorn-shaped-thing'),
      ]);
      expect(out, isEmpty);
    });

    test(
        'Caso 5: a mixed frame (person + tv + mouse + teddy bear + toy car) '
        'yields ONLY the two toys', () {
      final out = mapper.map([
        _yoloResult(className: 'person', confidence: 0.95),
        _yoloResult(className: 'tv', confidence: 0.9),
        _yoloResult(className: 'mouse', confidence: 0.88),
        _yoloResult(className: 'teddy bear', confidence: 0.8),
        _yoloResult(className: 'car', confidence: 0.7),
      ]);
      expect(out.length, 2);
      expect(out.map((d) => d.label).toList(), ['stuffed_animal', 'toy_car']);
    });
  });

  group('YoloDetectionMapper — coordinates', () {
    test('uses normalizedBox values directly without rescaling', () {
      // Rect.fromLTWH stores right/bottom and recomputes width/height, which
      // introduces tiny float drift; `closeTo` accepts that without losing
      // the contract that we map straight through.
      final out = mapper.map([
        _yoloResult(
          className: 'teddy bear',
          normalized: const Rect.fromLTWH(0.25, 0.50, 0.10, 0.20),
        ),
      ]);
      final box = out.single.box;
      expect(box.x, closeTo(0.25, 1e-9));
      expect(box.y, closeTo(0.50, 1e-9));
      expect(box.width, closeTo(0.10, 1e-9));
      expect(box.height, closeTo(0.20, 1e-9));
    });

    test('passes the YOLO confidence through unchanged', () {
      final out = mapper.map([
        _yoloResult(className: 'teddy bear', confidence: 0.73),
      ]);
      expect(out.single.confidence, 0.73);
    });
  });

  group('YoloDetectionMapper — mixed frames', () {
    test('keeps only the classes that pass the mapping', () {
      final raw = [
        _yoloResult(className: 'teddy bear', confidence: 0.9),
        _yoloResult(className: 'person', confidence: 0.95),
        _yoloResult(className: 'car', confidence: 0.7),
        _yoloResult(className: 'chair', confidence: 0.85),
        _yoloResult(className: 'sports ball', confidence: 0.6),
      ];
      final out = mapper.map(raw);
      expect(out.map((d) => d.label).toList(), [
        'stuffed_animal',
        'toy_car',
        'ball',
      ]);
    });
  });

  group('YoloDetectionMapper — producedLabels contract', () {
    test('every label the mapper can emit is in producedLabels', () {
      // Only the classes the 6.6 mapper still accepts.
      final samples = ['teddy bear', 'sports ball', 'car', 'truck', 'train'];
      for (final c in samples) {
        final out = mapper.map([_yoloResult(className: c)]);
        expect(
          YoloDetectionMapper.producedLabels.contains(out.single.label),
          isTrue,
          reason: 'label "${out.single.label}" from "$c" missing from '
              'producedLabels',
        );
      }
    });
  });

  group('YoloDetectionMapper — diagnostics', () {
    test('exposes toy-like mapping decisions without changing behavior', () {
      expect(mapper.mapLabelForDiagnostics('toy'), 'unknownToy');
      expect(mapper.mapLabelForDiagnostics('red toy'), 'unknownToy');
      expect(mapper.mapLabelForDiagnostics('object'), isNull);
      expect(
        YoloDetectionMapper.diagnosticInputLabels,
        containsAll(['toy', 'red toy', 'teddy bear']),
      );
    });
  });
}
