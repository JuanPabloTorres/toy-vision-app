# Skill: preserve-reusable-components

## Purpose
Ensure repeated UI patterns become reusable, token-driven components.

## When to use
Any time you create UI that resembles an existing pattern, or add a new shared visual
element.

## Required rules
- Build base components before feature UI
  ([reusable-components-guidelines.md](../reusable-components-guidelines.md)).
- Extract a component when a pattern appears more than once.
- Components take inputs and render; they read design tokens.
- Build composites from base components.

## Forbidden patterns
- Duplicated button/card/badge styling.
- Business logic, counting, or inference inside a component.
- Hardcoded design values bypassing tokens.
- Components reading global state or camera frames directly.

## Acceptance criteria
- No duplicated styling across screens.
- Shared patterns exist as components.
- Components are dumb, reusable, and token-driven.
- Composites reuse base components.
