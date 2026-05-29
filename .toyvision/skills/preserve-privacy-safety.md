# Skill: preserve-privacy-safety

## Purpose
Ensure the app never identifies people, saves video silently, or misuses images.

## When to use
Any time you touch the camera, storage, the save flow, the model, or anything handling
frames or user data.

## Required rules
- Detect toys, not people; ignore people and pets at the business layer
  ([privacy-safety-guidelines.md](../privacy-safety-guidelines.md)).
- Process frames in memory and discard them; no frame leaves the device by default.
- On save, persist summary only: total, per-category counts, timestamp, optional note.
- Allow deletion of saved summaries.
- Show the privacy note; any upload/backup is opt-in and reversible.

## Forbidden patterns
- Face recognition or child/person identification.
- Saving raw video or frames by default.
- Silent upload of frames or images.
- Training on user images without consent.
- Copy implying recognition of people or children.

## Acceptance criteria
- No video/frames saved or uploaded by default.
- People and pets are never counted.
- Saved data is summary-only and deletable.
- Privacy note is present; messaging is safe.
