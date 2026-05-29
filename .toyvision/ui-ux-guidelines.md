# UI/UX Guidelines — ToyVision Real-Time

The UI is camera-first, simple, modern, and safe. It **renders prepared state only**.

## Visual direction

- Full-screen camera preview.
- Clean, lightweight overlay.
- Translucent panels over the preview.
- Reusable buttons and rounded components.
- Clear labels, consistent spacing, friendly readable typography.
- Minimal debug noise.

## Main (live) screen — required elements

- camera preview;
- detection overlay;
- total toy counter;
- category count summary;
- pause/resume button;
- reset button;
- save-summary button;
- privacy note;
- model status indicator.

## The UI must not

- calculate count;
- calculate IoU;
- decide toy validity;
- show raw model output to normal users;
- show ignored objects unless debug mode is enabled;
- become visually cluttered.

## Screen states

Every data-driven view must define its states explicitly:

- `camera_permission_view` — permission not granted.
- `model_loading_view` — detector initializing / error.
- `empty_detection_hint` — running, no toys visible.
- active detection — toys visible, overlay + counters live.

## Reusable components (build before feature UI)

```text
AppButton
AppCard
AppBadge
AppStatusChip
AppGlassPanel
AppIconButton
LiveCounterPanel
ToySummaryPanel
DetectionOverlayPainter
EmptyDetectionHint
PrivacyNotice
```

## Component rule

If a visual pattern appears more than once, create a reusable component. Do not duplicate
button/card/badge styles by hand. See
[reusable-components-guidelines.md](reusable-components-guidelines.md).

## Design token rule

Centralize in `app_theme.dart` and shared constants:

- colors;
- typography;
- spacing;
- border radius;
- shadows;
- animation duration;
- overlay opacity.

## UX safety

- The privacy note must be visible on the live screen.
- User-facing copy must never imply the app identifies people or children.
- Never display certainty/confidence numbers as authoritative user-facing facts.

Guardrails: [skills/preserve-ui-ux-consistency.md](skills/preserve-ui-ux-consistency.md),
[skills/preserve-reusable-components.md](skills/preserve-reusable-components.md).
