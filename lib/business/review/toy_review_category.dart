/// User-facing categories the parent assigns to a confirmed toy.
///
/// Phase 4.1 product reframe: these are **product** categories, never model
/// labels. The detector never picks these — only the user does after seeing
/// a candidate box and deciding what it is. They map intentionally
/// generically: "car or truck" lumps both because telling them apart matters
/// less than counting one more vehicle-shaped toy.
///
/// [notToy] and [unsure] are present here so the review UI can offer them as
/// quick-tap options alongside the real categories. They mirror the
/// equivalent values in [ToyCandidateStatus] but live here as a UI vocabulary.
enum ToyReviewCategory {
  carOrTruck,
  ball,
  plush,
  blocks,
  dollOrFigure,
  train,
  puzzleOrBoardGame,
  book,
  otherToy,
  notToy,
  unsure,
}

extension ToyReviewCategoryDisplay on ToyReviewCategory {
  /// Human-readable label for the review UI. English; localization is a
  /// later phase.
  String get displayName => switch (this) {
        ToyReviewCategory.carOrTruck => 'Car / Truck',
        ToyReviewCategory.ball => 'Ball',
        ToyReviewCategory.plush => 'Plush',
        ToyReviewCategory.blocks => 'Blocks',
        ToyReviewCategory.dollOrFigure => 'Doll / Figure',
        ToyReviewCategory.train => 'Train',
        ToyReviewCategory.puzzleOrBoardGame => 'Puzzle / Board Game',
        ToyReviewCategory.book => 'Book',
        ToyReviewCategory.otherToy => 'Other toy',
        ToyReviewCategory.notToy => 'Not a toy',
        ToyReviewCategory.unsure => 'Unsure',
      };

  /// True for categories that contribute to the confirmed-toy count.
  /// `book`, `notToy`, and `unsure` do not.
  bool get countsAsToy => switch (this) {
        ToyReviewCategory.carOrTruck ||
        ToyReviewCategory.ball ||
        ToyReviewCategory.plush ||
        ToyReviewCategory.blocks ||
        ToyReviewCategory.dollOrFigure ||
        ToyReviewCategory.train ||
        ToyReviewCategory.puzzleOrBoardGame ||
        ToyReviewCategory.otherToy =>
          true,
        ToyReviewCategory.book ||
        ToyReviewCategory.notToy ||
        ToyReviewCategory.unsure =>
          false,
      };
}
