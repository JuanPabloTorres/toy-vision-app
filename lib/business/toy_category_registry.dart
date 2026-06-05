import 'toy_category_definition.dart';

/// Single source of truth for toy and ignored categories.
///
/// Phase 6.0 (Toy Cleanup YOLO) reset: the registry is now sized around what
/// the COCO-80 YOLO model actually emits via [YoloDetectionMapper]. Labels
/// like `toy_car`/`toy_truck`/`toy_train` are still here as canonical names —
/// the mapper translates COCO's `car`/`truck`/`train` to these — but the
/// generic ML Kit labels (`home_good`) have been retired alongside the
/// detector that produced them.
///
/// Three confidence tiers:
/// - **High-trust toys** (teddy bear, sports ball): threshold 0.40.
/// - **Likely-toy proxies** (toy_car/truck/train/vehicle): threshold 0.55
///   so the camera pointed out a window doesn't trigger them with a
///   half-second glimpse of a real car.
/// - **Needs-review** (`book`, `object`, `toy_outdoor`): threshold 0.45 —
///   they appear in the overlay but the user gates them via the review
///   panel.
class ToyCategoryRegistry {
  ToyCategoryRegistry._(this._byLabel);

  final Map<String, ToyCategoryDefinition> _byLabel;

  factory ToyCategoryRegistry.standard() {
    final entries = <ToyCategoryDefinition>[
      // --- High-trust toy categories (auto-counted) ---
      // Phase 6.6 precision pass: thresholds raised to cut false positives.
      // Kept >0.30 so FakeDetections.lowConfidenceDoll (0.30) still hits
      // the "below threshold" reject path in tests.
      _toyAt('stuffed_animal', 'Peluche', minimumConfidence: 0.30),
      // Device-audit finding (2026-06-04): RED/saturated balls are detected
      // with low confidence by the current model, so the old 0.45 gate dropped
      // them (mapped=1 valid=0). Lowered to 0.30 to recover them — the model's
      // own YOLOView floor is already 0.25, so this only admits the weak
      // red-toy sightings the gate was needlessly rejecting.
      _toyAt('ball', 'Pelota', minimumConfidence: 0.30),

      // --- Likely-toy proxies (vehicles in a child's room) ---
      // Device-audit finding (2026-06-04): the custom toy model emits toy
      // detections at 0.25–0.45, so the old 0.50 gate REJECTED real toys it
      // had already detected ("mapped=5 valid=0" in the field). Lowered to
      // 0.30 (just above the model's 0.25 floor) so detected toys are actually
      // selected. The old 0.50 guarded a real car seen out a window under the
      // COCO fallback — moot now that the toy model emits "toy car", not "car".
      _toyAt('toy_car', 'Carrito', minimumConfidence: 0.30),
      _toyAt('toy_truck', 'Camión', minimumConfidence: 0.30),
      _toyAt('toy_train', 'Tren', minimumConfidence: 0.30),
      _toyAt('toy_vehicle', 'Vehículo de juguete', minimumConfidence: 0.30),

      // --- Toy-model classes (emitted by the custom YOLO-World export;
      //     yolo26n/COCO never produces these, so they're inert until the
      //     toy .tflite is dropped into assets/models/). Threshold 0.40
      //     because the toy model is purpose-trained and more trustworthy. ---
      _toyAt('doll', 'Muñeco', minimumConfidence: 0.30),
      _toyAt('building_blocks', 'Bloques', minimumConfidence: 0.30),
      _toyAt('ring_stacker', 'Apilable', minimumConfidence: 0.30),
      _toyAt('action_figure', 'Figura', minimumConfidence: 0.30),
      _toyAt('puzzle', 'Rompecabezas', minimumConfidence: 0.30),

      // --- Needs-review (shown but the user confirms) ---
      _toyAt(
        'toy_outdoor',
        'Juguete (cometa/frisbee)',
        minimumConfidence: 0.35,
      ),
      _toyAt('book', 'Libro', minimumConfidence: 0.35),
      _toyAt(
        'unknownToy',
        'Juguete',
        minimumConfidence: 0.30,
        identity: ToyObjectIdentity.unknownToy,
      ),
      _uncertain('uncertain', 'Juguete'),

      // --- Ignored / negative categories (never counted; not drawn) ---
      // Kept in the registry so [isKnown] doesn't return false for any
      // COCO label that might still slip through the mapper.
      _ignored('not_toy', 'No es juguete'),
      _ignored('person', 'Persona'),
      _ignored('pet', 'Mascota'),
      _ignored('furniture', 'Mueble'),
      _ignored('unknown', 'Desconocido'),
    ];
    return ToyCategoryRegistry._({for (final e in entries) e.label: e});
  }

  /// Fallback definition for any label not present in the registry.
  static const ToyCategoryDefinition unknown = ToyCategoryDefinition(
    label: 'unknown',
    displayName: 'Desconocido',
    countsAsToy: false,
    minimumConfidence: 1.0,
    isIgnored: true,
    uiDisplayBehavior: UiDisplayBehavior.hideUnlessDebug,
    identity: ToyObjectIdentity.uncertain,
  );

  /// Look up a category, returning [unknown] when the label is not registered.
  ToyCategoryDefinition lookup(String label) => _byLabel[label] ?? unknown;

  bool isKnown(String label) => _byLabel.containsKey(label);

  Iterable<ToyCategoryDefinition> get all => _byLabel.values;

  static ToyCategoryDefinition _toyAt(
    String label,
    String displayName, {
    required double minimumConfidence,
    ToyObjectIdentity identity = ToyObjectIdentity.recognizedToy,
  }) =>
      ToyCategoryDefinition(
        label: label,
        displayName: displayName,
        countsAsToy: true,
        minimumConfidence: minimumConfidence,
        isIgnored: false,
        uiDisplayBehavior: UiDisplayBehavior.show,
        identity: identity,
      );

  static ToyCategoryDefinition _ignored(String label, String displayName) =>
      ToyCategoryDefinition(
        label: label,
        displayName: displayName,
        countsAsToy: false,
        minimumConfidence: 1.0,
        isIgnored: true,
        uiDisplayBehavior: UiDisplayBehavior.hideUnlessDebug,
        identity: ToyObjectIdentity.notToy,
      );

  static ToyCategoryDefinition _uncertain(String label, String displayName) =>
      ToyCategoryDefinition(
        label: label,
        displayName: displayName,
        countsAsToy: false,
        minimumConfidence: 1.0,
        isIgnored: false,
        uiDisplayBehavior: UiDisplayBehavior.hideUnlessDebug,
        identity: ToyObjectIdentity.uncertain,
      );
}
