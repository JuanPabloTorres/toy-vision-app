/// Where a detected object sits in the human review flow.
///
/// Phase 4.1 product reframe: the on-device detector (ML Kit, mock, or any
/// future custom model) emits raw boxes. The parent — not the detector —
/// decides whether each box is a toy worth counting. This enum captures that
/// human decision as a value the rest of the pipeline can act on.
///
/// Only [confirmedToy] contributes to the confirmed-toy count surfaced to the
/// user. [pending] and [unsure] are "needs review"; [notToy] and
/// [ignoredAutomatic] are excluded from the count.
enum ToyCandidateStatus {
  /// Detector saw an object; the user has not reviewed it yet.
  pending,

  /// The user marked this object as a real toy. Counted.
  confirmedToy,

  /// The user explicitly marked this object as not a toy. Not counted.
  notToy,

  /// The user couldn't tell. Not counted, but stays in the review list.
  unsure,

  /// Auto-rejected by business rules without user interaction (e.g. detector
  /// label was `person` or `pet`). Not counted; not shown in the review list
  /// unless debug.
  ignoredAutomatic,
}
