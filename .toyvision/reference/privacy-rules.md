# Dataset Privacy Rules

These rules govern every image, label, and artifact used to train, evaluate, or
fine-tune a ToyVision detector. They are an **extension** of the app-level
guarantees in [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md),
not a replacement. Where this file and that file disagree, the app-level
guarantees win and this file must be updated.

ToyVision detects **toys, not people**. The dataset must encode that intent
end-to-end — from capture, through labeling, through retention.

## Status reminder

- The default detector is `MockToyDetector`. Real inference is gated behind a
  fallback path and is not enabled.
- **Phase 2d physical-device QA is BLOCKED.** No QA has passed on real
  hardware.
- No `.tflite` file is committed. No dataset has been downloaded or assembled
  under these rules yet. This document is a forward-looking specification.

## App-level guarantees this dataset must respect

Reiterated from [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md):

- No face recognition.
- No child identification.
- No person identity labels.
- No silent image upload.
- No silent video recording.
- No training on user images without explicit consent.
- No saving video by default.

The dataset rules below exist so that a model trained under them **cannot**
violate these guarantees, even by accident.

## Non-negotiable dataset rules

### 1. No faces in training images

- Training images must not contain identifiable human faces.
- If a face is unavoidable in the frame (e.g. a doll held near a person), the
  face must be **cropped out** or **irreversibly blurred** before the image
  enters the dataset.
- "Irreversibly blurred" means a destructive blur applied to the saved file —
  not a viewer-side mask. The original face pixels must not be recoverable
  from the dataset artifact.
- Profile, partial, and silhouette faces still count. If a human could
  recognize the person, it is identifiable.

### 2. No identifiable children, ever

- No image that could identify a child may be added to the dataset, under any
  circumstance, with or without consent.
- This is stricter than the face rule: crop/blur is **not** an acceptable
  workaround for children. The whole image is rejected.
- Hands, feet, or clothing of a child are acceptable only when they cannot
  reasonably identify the child and the image is otherwise toy-focused.
- The labeling pipeline must never produce a `child` class, a `minor` class,
  or any age-related person label. This stacks with the app-level
  no-person-identity rule.

### 3. No identifiable home or private information

- Avoid capturing addresses, mail, screens showing personal accounts,
  documents, ID cards, prescription bottles, calendars, schoolwork with names,
  or anything that ties the image to a specific household.
- When such items appear in the background, either reshoot on a neutral
  surface or crop/blur the identifying region before adding the image.
- Prefer plain backgrounds (see rule 6) precisely so this problem rarely
  arises.

### 4. No family photos without explicit, written consent

- No image depicting a family member, friend, or any identifiable adult may
  enter the dataset without **explicit, written, revocable** consent from
  every adult in the image.
- Consent must record: who consented, what images, what purpose (training a
  toy detector), retention scope (see rule 7), and how to revoke.
- Consent for one image is not consent for another. Consent for training is
  not consent for publication.
- Children cannot consent and parents cannot consent on a child's behalf for
  this dataset. Rule 2 still applies — children are excluded regardless.

### 5. No third-party labeling or training services without consent

- Do not upload images to third-party labeling services, cloud annotation
  tools, or hosted training platforms unless every person depicted has
  consented (per rule 4) **and** the service's terms are reviewed and
  recorded.
- Prefer **on-device** or **self-hosted** labeling tools. The default
  assumption is that images stay on the labeler's machine.
- Public/stock images licensed for ML training are exempt from rule 4 but
  still subject to rules 1, 2, 3, and 6.
- This rule is the dataset-side counterpart to the app-level "no silent
  upload" guarantee.

### 6. Prefer toy-only photographs

- The strongly preferred capture is: **a toy (or toys) on a neutral surface,
  with no people, no pets, and no identifying background.**
- Neutral surfaces include plain floor, plain table, plain rug, plain fabric.
- This pattern sidesteps rules 1–4 entirely and is the fastest way to grow
  the dataset safely.
- Toy-only images still must respect the class taxonomy and labeling
  guidelines — see [class-taxonomy.md](class-taxonomy.md) and
  [labeling-guidelines.md](labeling-guidelines.md).

### 7. Retention is bounded to one model version

- An image is retained **only for the model version it trained.**
- When a new model version supersedes the version an image was used for, that
  image must either be:
  - explicitly re-approved for the new version under these same rules; or
  - deleted from the dataset and from all derived artifacts.
- "Derived artifacts" includes augmented copies, tiled crops, cached
  tensors, label files, and any backup.
- Model versioning is tracked in [model-versioning.md](model-versioning.md).
  Retention scope is keyed off the model version recorded there.

### 8. Deletion procedure

Every image must be deletable. The procedure:

1. Locate the image by its dataset ID in the manifest used by
   [dataset-plan.md](dataset-plan.md).
2. Remove the source file from the dataset storage location.
3. Remove the corresponding label file(s) and any per-image metadata.
4. Remove all augmented or cached derivatives keyed to that ID.
5. Remove the entry from the manifest and from any train/val/test split file.
6. If the image was used in a released model version, record the deletion in
   that version's provenance entry — the trained weights are not retroactively
   purged, but the source is gone and the version is flagged.
7. If the image was uploaded to any third-party service under rule 5, issue a
   deletion request to that service and record the response.

Consent revocation (rule 4) triggers this procedure automatically for every
image covered by the revoked consent.

## What the model must not learn

These rules combine to ensure the trained model:

- has no `face` class, no `child` class, no `person identity` class;
- has no signal that rewards recognizing a specific household, room, or
  person;
- treats `person` and `pet` only as **ignored** categories (see
  [class-taxonomy.md](class-taxonomy.md)), never as identification targets.

The model only detects toys. Final counting, validity, confidence
acceptability, duplicate identity, and ignored behavior all live in the
business layer — see [../business-logic-principles.md](../business-logic-principles.md).

## Enforcement

- The Code Review Agent rejects any dataset change, label schema change, or
  training script change that weakens a rule above.
- The QA Validation Agent treats a violation of these rules as a release
  blocker for the affected model version.
- Any image whose provenance cannot be reconstructed (capture source,
  consent status, retention scope) must be removed from the dataset.

## Related documents

- [../privacy-safety-guidelines.md](../privacy-safety-guidelines.md) —
  app-level privacy guarantees these rules extend.
- [../ai-model-guidelines.md](../ai-model-guidelines.md) — detector contract
  and mock-first policy.
- [dataset-plan.md](dataset-plan.md) — sources, sizes, splits.
- [class-taxonomy.md](class-taxonomy.md) — canonical classes and ignored
  categories.
- [labeling-guidelines.md](labeling-guidelines.md) — box rules and QA.
- [model-versioning.md](model-versioning.md) — provenance and retention
  keying.
