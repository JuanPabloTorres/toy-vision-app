/// Mapping from a COCO 80-class detection model's output indices to
/// ToyVision registry labels.
///
/// Used by [CocoSsdToyModelConfig] so a stock COCO-trained TFLite model (SSD
/// MobileNet V1/V2, EfficientDet Lite) can flow into the existing
/// `TfliteToyDetectorAdapter` without adapter changes. The model still does
/// no business work — the business layer drops `'person'`, `'pet'`, ignored
/// categories, and `'unknown'` per [ToyCategoryRegistry] and
/// [ToyDetectionRules].
///
/// See `.toyvision/model-training/open-source-model-evaluation.md` for the
/// rationale, the prototype-only `car`/`truck` caveat, and the limits of a
/// COCO baseline.
class CocoLabelMap {
  const CocoLabelMap._();

  /// Canonical COCO 80 class names in standard model-output index order.
  static const List<String> cocoLabels = [
    'person',
    'bicycle',
    'car',
    'motorcycle',
    'airplane',
    'bus',
    'train',
    'truck',
    'boat',
    'traffic light',
    'fire hydrant',
    'stop sign',
    'parking meter',
    'bench',
    'bird',
    'cat',
    'dog',
    'horse',
    'sheep',
    'cow',
    'elephant',
    'bear',
    'zebra',
    'giraffe',
    'backpack',
    'umbrella',
    'handbag',
    'tie',
    'suitcase',
    'frisbee',
    'skis',
    'snowboard',
    'sports ball',
    'kite',
    'baseball bat',
    'baseball glove',
    'skateboard',
    'surfboard',
    'tennis racket',
    'bottle',
    'wine glass',
    'cup',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'banana',
    'apple',
    'sandwich',
    'orange',
    'broccoli',
    'carrot',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'chair',
    'couch',
    'potted plant',
    'bed',
    'dining table',
    'toilet',
    'tv',
    'laptop',
    'mouse',
    'remote',
    'keyboard',
    'cell phone',
    'microwave',
    'oven',
    'toaster',
    'sink',
    'refrigerator',
    'book',
    'clock',
    'vase',
    'scissors',
    'teddy bear',
    'hair drier',
    'toothbrush',
  ];

  /// COCO index -> ToyVision registry label, in the same order as [cocoLabels].
  ///
  /// Every entry is a label known to [ToyCategoryRegistry]. Labels that don't
  /// correspond cleanly to a toy or ignored category map to `'unknown'`, which
  /// the business layer drops. Indices in [prototypeOnlyIndices] are explicit
  /// prototype-only mappings — they cross the toy/real-object boundary and
  /// must not ship as production behaviour.
  static const List<String> toyVisionLabels = [
    /*  0 person          */ 'person',
    /*  1 bicycle         */ 'unknown',
    /*  2 car             */ 'toy_car', // PROTOTYPE-ONLY
    /*  3 motorcycle      */ 'unknown',
    /*  4 airplane        */ 'unknown',
    /*  5 bus             */ 'unknown',
    /*  6 train           */ 'unknown',
    /*  7 truck           */ 'toy_truck', // PROTOTYPE-ONLY
    /*  8 boat            */ 'unknown',
    /*  9 traffic light   */ 'unknown',
    /* 10 fire hydrant    */ 'unknown',
    /* 11 stop sign       */ 'unknown',
    /* 12 parking meter   */ 'unknown',
    /* 13 bench           */ 'furniture',
    /* 14 bird            */ 'unknown',
    /* 15 cat             */ 'pet',
    /* 16 dog             */ 'pet',
    /* 17 horse           */ 'unknown',
    /* 18 sheep           */ 'unknown',
    /* 19 cow             */ 'unknown',
    /* 20 elephant        */ 'unknown',
    /* 21 bear            */ 'unknown',
    /* 22 zebra           */ 'unknown',
    /* 23 giraffe         */ 'unknown',
    /* 24 backpack        */ 'clothes',
    /* 25 umbrella        */ 'unknown',
    /* 26 handbag         */ 'clothes',
    /* 27 tie             */ 'clothes',
    /* 28 suitcase        */ 'clothes',
    /* 29 frisbee         */ 'unknown',
    /* 30 skis            */ 'unknown',
    /* 31 snowboard       */ 'unknown',
    /* 32 sports ball     */ 'ball',
    /* 33 kite            */ 'unknown',
    /* 34 baseball bat    */ 'unknown',
    /* 35 baseball glove  */ 'unknown',
    /* 36 skateboard      */ 'unknown',
    /* 37 surfboard       */ 'unknown',
    /* 38 tennis racket   */ 'unknown',
    /* 39 bottle          */ 'bottle',
    /* 40 wine glass      */ 'unknown',
    /* 41 cup             */ 'cup',
    /* 42 fork            */ 'unknown',
    /* 43 knife           */ 'unknown',
    /* 44 spoon           */ 'unknown',
    /* 45 bowl            */ 'unknown',
    /* 46 banana          */ 'unknown',
    /* 47 apple           */ 'unknown',
    /* 48 sandwich        */ 'unknown',
    /* 49 orange          */ 'unknown',
    /* 50 broccoli        */ 'unknown',
    /* 51 carrot          */ 'unknown',
    /* 52 hot dog         */ 'unknown',
    /* 53 pizza           */ 'unknown',
    /* 54 donut           */ 'unknown',
    /* 55 cake            */ 'unknown',
    /* 56 chair           */ 'furniture',
    /* 57 couch           */ 'furniture',
    /* 58 potted plant    */ 'unknown',
    /* 59 bed             */ 'bed',
    /* 60 dining table    */ 'furniture',
    /* 61 toilet          */ 'furniture',
    /* 62 tv              */ 'unknown',
    /* 63 laptop          */ 'unknown',
    /* 64 mouse           */ 'unknown',
    /* 65 remote          */ 'remote_control',
    /* 66 keyboard        */ 'unknown',
    /* 67 cell phone      */ 'phone',
    /* 68 microwave       */ 'unknown',
    /* 69 oven            */ 'unknown',
    /* 70 toaster         */ 'unknown',
    /* 71 sink            */ 'unknown',
    /* 72 refrigerator    */ 'unknown',
    /* 73 book            */ 'book',
    /* 74 clock           */ 'unknown',
    /* 75 vase            */ 'unknown',
    /* 76 scissors        */ 'unknown',
    /* 77 teddy bear      */ 'stuffed_animal',
    /* 78 hair drier      */ 'unknown',
    /* 79 toothbrush      */ 'unknown',
  ];

  /// Indices whose mapping is prototype-only: a real-world object the COCO
  /// model recognises that we tag as a toy class for the purpose of validating
  /// the runtime path. Production must replace this with a custom toy detector
  /// before relying on these classes.
  static const Set<int> prototypeOnlyIndices = {
    2, // car -> toy_car
    7, // truck -> toy_truck
  };

  /// `true` if [cocoIndex] is a prototype-only mapping.
  static bool isPrototypeOnly(int cocoIndex) =>
      prototypeOnlyIndices.contains(cocoIndex);
}
