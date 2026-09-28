# Testing Strategy

## Required domain coverage

- temporal evidence creates snapshots only after stability;
- one-frame noise is ignored and brief dropout is tolerated;
- initial snapshots remain immutable;
- technical progress cannot become negative;
- visible energy never decreases;
- reward events and milestones are idempotent;
- full energy enters final checking, not completion;
- one zero snapshot cannot finish;
- unstable scenes cannot create a completion candidate;
- confirmation is valid only from `completionCandidate`;
- restart clears snapshots, progress, and reward ledger.

## UI and storage coverage

- Tobi and one primary action dominate Kid Mode;
- no technical detector or selected-object UI leaks into Kid Mode;
- reduced motion, small screens, and touch targets remain safe;
- persisted records contain only game estimates, timestamps, and flags;
- current-schema history survives restart and reset works.

Run focused tests while editing, then `flutter analyze` and the full
`flutter test` suite. Device certification uses the exact newly hashed APK.
