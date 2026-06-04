import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../models/bounding_box.dart';
import '../models/raw_detection.dart';

/// Conservative mapping from COCO-80 class names (what `yolo26n` emits) to the
/// ToyVision registry labels.
///
/// Phase 6.0 product call: we don't have a toy-specific detector yet. To avoid
/// the app "shouting" at the user about every chair and laptop on screen, this
/// mapper only forwards classes that have a reasonable chance of being a toy
/// on the floor of a child's room. Anything else is dropped at the very edge
/// of the pipeline — it never reaches business rules, tracking, or counting.
///
/// Three buckets:
///
/// 1. **Direct toys** (`_autoToys`): COCO has a real class that *is* the toy.
///    Mapped to the registry's specific toy label.
///       teddy bear   → stuffed_animal
///       sports ball  → ball
///
/// 2. **Likely toys in a child's room** (`_likelyToyProxies`): COCO classes
///    that are usually full-size objects (car, truck, train, airplane, …)
///    but in this product's context — pointing the camera at a kid's floor —
///    they're almost always miniature toys. Mapped to the closest toy label.
///       car / truck → toy_car / toy_truck
///       train       → toy_train
///       airplane / boat / bicycle / motorcycle / bus → toy_vehicle
///
/// 3. **Worth a second look** (`_needsReview`): COCO classes that could be
///    toys (kite, frisbee, skateboard) or could be the real adult thing
///    (book, backpack, suitcase, scissors). Mapped to a generic registry
///    label so the user can confirm via the review panel; never auto-counted.
///       kite / frisbee / skateboard → toy_outdoor
///       book / backpack / suitcase / scissors → object
///
/// 4. **Drop silently** (default): every other COCO class (person, chair,
///    couch, bed, tv, laptop, cell phone, fridge, microwave, sink, toilet,
///    oven, clock, dog, cat, …). Returns `null` so the detection is not
///    even added to the output list.
class YoloDetectionMapper {
  const YoloDetectionMapper();

  /// Convert one frame's raw YOLO results into the app's [RawDetection]
  /// shape, dropping non-relevant classes entirely.
  ///
  /// Coordinates: uses `YOLOResult.normalizedBox`, which is already in the
  /// `[0, 1]` unit square — matches our [BoundingBox] contract directly,
  /// no rotation or scaling required.
  List<RawDetection> map(List<YOLOResult> yoloResults) {
    final out = <RawDetection>[];
    for (final r in yoloResults) {
      final mapped = _mapLabel(r.className);
      if (mapped == null) continue;
      out.add(
        RawDetection(
          label: mapped,
          confidence: r.confidence,
          box: BoundingBox(
            x: r.normalizedBox.left,
            y: r.normalizedBox.top,
            width: r.normalizedBox.width,
            height: r.normalizedBox.height,
          ),
        ),
      );
    }
    return out;
  }

  /// Returns the registry label for a detector class name, or `null` to
  /// drop the detection. Case-insensitive. Checks, in order:
  /// 1. the custom toy-model prompt labels (`toy car`, `doll`, `ring
  ///    stacker`, …) — only ever emitted when `assets/models/toys.tflite`
  ///    is loaded;
  /// 2. the COCO direct toys (`teddy bear`, `sports ball`);
  /// 3. the COCO vehicle proxies (`car`/`truck`/`train`);
  /// 4. otherwise drop.
  String? _mapLabel(String rawClass) {
    final key = rawClass.toLowerCase().trim();
    final toyModel = toyModelLabels[key];
    if (toyModel != null) return toyModel;
    final direct = _autoToys[key];
    if (direct != null) return direct;
    final likely = _likelyToyProxies[key];
    if (likely != null) return likely;
    final review = _needsReview[key];
    if (review != null) return review;
    return null; // explicitly dropped
  }

  /// Maps the prompt strings baked into the custom YOLO-World export
  /// (`tools/toy_model_export/`) to registry labels. **These keys MUST
  /// stay in sync with the `PROMPTS` list in the Python export script** —
  /// the exported model's class names are exactly those prompts, and the
  /// plugin surfaces them verbatim as `YOLOResult.className`.
  static const Map<String, String> toyModelLabels = {
    'teddy bear': 'stuffed_animal',
    'stuffed animal': 'stuffed_animal',
    'plush toy': 'stuffed_animal',
    'doll': 'doll',
    'toy car': 'toy_car',
    'toy truck': 'toy_truck',
    'fire truck': 'toy_truck',
    'firetruck': 'toy_truck',
    'toy train': 'toy_train',
    // Aircraft toys. Deliberately uses "toy …"/"helicopter" terms that
    // COCO-80 never emits (COCO only has bare "airplane"), so adding them
    // here can't re-introduce COCO false positives — only the custom toy
    // model produces these class names. Fixes the "red firefighter
    // helicopter detected as toilet" case once the toy model is loaded.
    'helicopter': 'toy_vehicle',
    'toy helicopter': 'toy_vehicle',
    'red helicopter': 'toy_vehicle',
    'toy airplane': 'toy_vehicle',
    'toy plane': 'toy_vehicle',
    'airplane': 'toy_vehicle',
    'plane': 'toy_vehicle',
    'spaceship': 'toy_vehicle',
    'toy spaceship': 'toy_vehicle',
    'rocket': 'toy_vehicle',
    'toy rocket': 'toy_vehicle',
    'robot': 'action_figure',
    'toy robot': 'action_figure',
    'dinosaur': 'action_figure',
    'toy dinosaur': 'action_figure',
    'ball': 'ball',
    'building blocks': 'building_blocks',
    'lego': 'building_blocks',
    'ring stacker': 'ring_stacker',
    'stacking rings': 'ring_stacker',
    'action figure': 'action_figure',
    'puzzle': 'puzzle',
    'red car': 'toy_car',
    'red toy': 'object',
    'toy': 'object',
  };

  /// COCO classes that essentially **are** toys in any context. The mapper
  /// emits the registry label directly and the business layer treats them
  /// as toys for counting.
  static const Map<String, String> _autoToys = {
    'teddy bear': 'stuffed_animal',
    'sports ball': 'ball',
  };

  /// COCO classes that are full-size objects but, in a child's room, are
  /// overwhelmingly miniature toys.
  ///
  /// COCO classes that, indoors in a child's room, are almost always the
  /// toy version of the object.
  ///
  /// Phase 6.7: `airplane` added back. COCO-80 *does* have an `airplane`
  /// class, and a real plane indoors is essentially impossible — so an
  /// `airplane` detection in this app is a toy airplane. This fixes "a toy
  /// airplane isn't recognized as a toy". (Note: COCO has **no**
  /// `helicopter` class, so the red firefighter helicopter still needs the
  /// custom toy model.) `boat`/`bicycle`/`motorcycle`/`bus` stay dropped —
  /// they're rarer as toys and noisier.
  static const Map<String, String> _likelyToyProxies = {
    'car': 'toy_car',
    'truck': 'toy_truck',
    'train': 'toy_train',
    'airplane': 'toy_vehicle',
    'aeroplane': 'toy_vehicle',
  };

  /// Phase 6.6: the old "needs-review" bucket (kite/frisbee/skateboard/
  /// book/backpack/suitcase/scissors) was removed entirely. Those COCO
  /// classes are almost never the toy the child is cleaning up, and they
  /// drove most of the false positives. They are now dropped at the edge
  /// like any other non-toy class. The real fix for broader toy coverage
  /// is a toy-trained model (see tools/ + YoloModelConfig.modelPath).
  static const Map<String, String> _needsReview = {};

  /// The full set of registry labels this mapper can emit (COCO fallback
  /// + custom toy model). Used by tests and to assert every produced
  /// label is registered.
  static const Set<String> producedLabels = {
    'stuffed_animal',
    'ball',
    'toy_car',
    'toy_truck',
    'toy_train',
    'toy_vehicle',
    'doll',
    'building_blocks',
    'ring_stacker',
    'action_figure',
    'puzzle',
    'object',
  };
}
