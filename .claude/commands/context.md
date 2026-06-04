---
description: Summarize current project context, architecture, and key decisions.
---

Summarize the current state of ToyVision for someone picking up the work. Read-only.

Cover:
- **Purpose** — what the product does (live toy detection, tracking, counting; local-first, privacy-first).
- **Phase** — current development phase and what is in/out of scope (see `.toyvision/`).
- **Architecture** — layers and their boundaries (UI / state / services / inference / storage / validation), key files per layer.
- **Detection pipeline** — detector → tracking → business rules → counting → UI overlay; where throttling/single-inflight live.
- **Recent decisions** — pull from git log and ruflo memory (memory_search) if available.
- **Open risks / pending** — what is mocked vs real (e.g. Phase 1 mock detector), what is deferred.

Keep it tight and navigable with file links. This is orientation, not an audit.
