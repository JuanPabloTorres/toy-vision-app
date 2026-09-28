# Preserve UI/UX Consistency

- Render only `KidGameState` in the active game.
- Keep Tobi and energy visually primary.
- Use shared components and design tokens.
- Never expose detection boxes, labels, identity, confidence, or exact estimates
  in normal Kid Mode.
- Respect reduced motion, touch sizing, text scaling, and small screens.
- Keep debug diagnostics behind debug-only interaction.
