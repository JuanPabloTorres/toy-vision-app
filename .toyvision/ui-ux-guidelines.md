# UI/UX Guidelines

Kid Mode is designed for preschool attention and motor skills.

- Tobi is the dominant visual and energy is the main feedback.
- One primary action is visually unmistakable.
- Copy is short, positive, and avoids claims of exact physical-room truth.
- The child may clean any supported toy in any order.
- Camera output stays visually subordinate: no boxes, labels, confidence,
  tracker IDs, or technical counters in normal Kid Mode.
- Final completion always asks `¿Terminaste?` with large `Sí` and secondary
  `Seguir` actions.
- Touch targets are at least 48 logical pixels.
- Layouts must survive small screens and text scaling without overflow.
- Reduced-motion preference disables repeating/decorative motion.
- Diagnostics are debug-only and activated by a non-obvious long press.

Shared controls, Tobi, status animation, energy, and celebration visuals belong
in reusable components; business decisions never belong in widgets.
