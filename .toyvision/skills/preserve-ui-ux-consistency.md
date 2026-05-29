# Skill: preserve-ui-ux-consistency

## Purpose
Keep screens simple, consistent, and safe; the UI renders prepared state only.

## When to use
Any time you build or change a screen, panel, or screen state in `ui/` or
`camera/screens/`.

## Required rules
- Render `LiveDetectionState`; compute nothing in the UI.
- Define explicit states: permission, loading/error, empty, active.
- Use design tokens from `app_theme.dart`.
- Show the privacy note and a clear model status indicator.
- Keep layouts uncluttered and readable.

## Forbidden patterns
- Calculating count, IoU, or category validity in the UI.
- Showing raw model output or ignored objects to normal users.
- Copy implying recognition of people or children.
- Hardcoded colors, spacing, or radii.
- Visual clutter or inconsistent styling.

## Acceptance criteria
- The screen reflects state with no business computation.
- All four screen states are handled.
- Tokens are used throughout; no hardcoded visuals.
- Privacy note is visible; messaging is safe.
