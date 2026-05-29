import 'toy_category_definition.dart';

/// The single source of truth for toy and ignored categories.
///
/// Per governance, no other file may define a parallel category map, and a
/// label the registry does not know is treated as [unknown] and ignored — never
/// counted. Changing a model label requires updating this registry in the same
/// change.
class ToyCategoryRegistry {
  ToyCategoryRegistry._(this._byLabel);

  final Map<String, ToyCategoryDefinition> _byLabel;

  factory ToyCategoryRegistry.standard() {
    final entries = <ToyCategoryDefinition>[
      // --- Toy categories (count as toys) ---
      _toy('toy_car', 'Toy car'),
      _toy('toy_truck', 'Toy truck'),
      _toy('doll', 'Doll'),
      _toy('stuffed_animal', 'Stuffed animal'),
      _toy('building_blocks', 'Building blocks'),
      _toy('ball', 'Ball'),
      _toy('action_figure', 'Action figure'),
      _toy('toy_train', 'Toy train'),
      _toy('puzzle', 'Puzzle'),
      _toy('board_game', 'Board game'),
      // Explicit non-toy class from the model.
      _ignored('not_toy', 'Not a toy'),

      // --- Ignored / negative categories (never counted, hidden by default) ---
      _ignored('person', 'Person'),
      _ignored('pet', 'Pet'),
      _ignored('shoe', 'Shoe'),
      _ignored('clothes', 'Clothes'),
      _ignored('bottle', 'Bottle'),
      _ignored('cup', 'Cup'),
      _ignored('furniture', 'Furniture'),
      _ignored('bed', 'Bed'),
      _ignored('pillow', 'Pillow'),
      _ignored('phone', 'Phone'),
      _ignored('remote_control', 'Remote control'),
      _ignored('book', 'Book'),
      _ignored('unknown', 'Unknown'),
    ];
    return ToyCategoryRegistry._({for (final e in entries) e.label: e});
  }

  /// Fallback definition for any label not present in the registry.
  static const ToyCategoryDefinition unknown = ToyCategoryDefinition(
    label: 'unknown',
    displayName: 'Unknown',
    countsAsToy: false,
    minimumConfidence: 1.0,
    isIgnored: true,
    uiDisplayBehavior: UiDisplayBehavior.hideUnlessDebug,
  );

  /// Look up a category, returning [unknown] when the label is not registered.
  ToyCategoryDefinition lookup(String label) => _byLabel[label] ?? unknown;

  bool isKnown(String label) => _byLabel.containsKey(label);

  Iterable<ToyCategoryDefinition> get all => _byLabel.values;

  static ToyCategoryDefinition _toy(String label, String displayName) =>
      ToyCategoryDefinition(
        label: label,
        displayName: displayName,
        countsAsToy: true,
        minimumConfidence: 0.55,
        isIgnored: false,
        uiDisplayBehavior: UiDisplayBehavior.show,
      );

  static ToyCategoryDefinition _ignored(String label, String displayName) =>
      ToyCategoryDefinition(
        label: label,
        displayName: displayName,
        countsAsToy: false,
        minimumConfidence: 1.0,
        isIgnored: true,
        uiDisplayBehavior: UiDisplayBehavior.hideUnlessDebug,
      );
}
