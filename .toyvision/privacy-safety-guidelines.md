# Privacy and Safety Guidelines — ToyVision Real-Time

ToyVision detects **toys, not people**. These rules are non-negotiable and override any
feature request that conflicts with them.

## Non-negotiable rules

- No face recognition.
- No child identification.
- No person identity labels.
- No silent image upload.
- No silent video recording.
- No training on user images without explicit consent.
- No saving video by default.
- Ignore people and pets — they are never counted.
- Always allow the user to delete saved summaries.

## Default save behavior

When the user taps **save**, persist a **summary only**:

- total toys;
- count by category;
- timestamp;
- optional note.

**Do not save raw video. Do not save frames.**

## Data handling defaults

- Camera frames are processed in memory for live detection and then discarded.
- No frame leaves the device by default.
- The backend (if present) never receives frames in the live loop.
- Any future upload, backup, or feedback-collection feature must be **opt-in**, clearly
  disclosed, and reversible.

## User-facing transparency

- The live screen shows a visible `PrivacyNotice`.
- Copy must never imply the app recognizes people or children.
- The model status indicator communicates state without exposing raw model internals.

## Enforcement

- The QA Validation Agent verifies privacy behavior as part of acceptance testing.
- The Code Review Agent rejects any change that saves video, uploads frames, adds person
  identification, or weakens a default above.
- People and pets must be filtered at the Business Logic Layer regardless of what the
  model returns.

Guardrail: [skills/preserve-privacy-safety.md](skills/preserve-privacy-safety.md).
