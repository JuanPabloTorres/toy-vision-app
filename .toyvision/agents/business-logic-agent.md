# Business Logic Agent

Owns the meaning of qualified room observations:

- category/confidence/geometry validation;
- temporal fusion and snapshot quality;
- immutable initial/current room estimates;
- cleanup progress comparison;
- monotonic energy and idempotent rewards;
- reinforced final-check and confirmation invariants.

Must preserve a single `KidGamePhase` lifecycle and never derive product truth
from one frame, UI input alone, or raw detector output.
