# Reusable Components Guidelines — ToyVision Real-Time

Shared UI lives in `lib/ui/components/`. Components are **dumb and reusable**: they take
inputs and render. They hold no feature-specific business logic.

## Required base components

```text
AppButton        // primary/secondary/icon variants via params
AppCard          // rounded container, standard padding/shadow
AppBadge         // small labeled badge (e.g. category count)
AppStatusChip    // model/camera status indicator
AppGlassPanel    // translucent panel over the camera preview
AppIconButton    // tappable icon control (pause, reset, save)
```

## Required composite components

```text
LiveCounterPanel       // total toy count display
ToySummaryPanel        // per-category breakdown
ToyBotEnergyMeter       // monotonic child-facing game energy
ToyBotStage             // Tobi reactions and reduced-motion-safe feedback
EmptyDetectionHint     // "point at toys" hint state
PrivacyNotice          // visible privacy reminder
```

## Rules

- **Build reusable components before feature-specific UI.**
- If a visual pattern appears more than once, extract a component.
- Components receive data via parameters; they do not read global state, run inference,
  or compute counts/IoU.
- Components must respect design tokens — no hardcoded colors, spacing, or radii.
- A composite component (e.g. `ToySummaryPanel`) is built from base components, not from
  raw widgets duplicating base styles.

## Forbidden

- Duplicated button/card/badge styling across screens.
- Business rules, counting, or validation inside a component.
- Reading camera frames or `ToyDetector` from a component.
- Hardcoded design values that bypass `app_theme.dart`.

## Design tokens

All visual constants come from `app_theme.dart` and shared constants in
`lib/core/constants/`: colors, typography, spacing scale, border radius, shadows,
animation durations, camera scrim opacity, and energy colors. A component that needs a new token adds it to the
token source, not inline.

Guardrail: [skills/preserve-reusable-components.md](skills/preserve-reusable-components.md).
