# Toy Vision controlled demo script

This script is for a controlled demo with an adult present. It is not a
children-unsupervised protocol.

## 1. Space preparation

- Use a clear floor area of about 1.5 x 1.5 meters.
- Remove clutter that looks like toys unless it is part of the test.
- Keep pets, people, TV screens, and moving objects out of the camera view.
- Put the phone in the child's hands only after the adult has opened the
  camera mission screen.

## 2. Recommended toys

- Start with 1 large, high-contrast toy.
- Then try 2 or 3 toys with clear spacing.
- Avoid grouped or partially hidden toys until the simple demo succeeds.

## 3. Lighting

- Use bright, even room light.
- Avoid backlighting, dark corners, shiny reflections, and fast shadows.
- Do the low-light scenario only as a technical test, not as the first demo.

## 4. Demo steps

1. Adult opens Toy Vision and starts a cleanup mission.
2. Child points the camera at the prepared area.
3. Adult waits until the app says it found toys.
4. Child follows the highlighted target.
5. Child picks up only the highlighted toy.
6. Adult watches the hidden diagnostics if the app hesitates.
7. Repeat until the app says the area is clean.

## 5. What the child should see or hear

- "Estoy mirando el área."
- "Encontré 1 juguete." or "Encontré 3 juguetes."
- "Vamos por este juguete."
- "Lo perdí un momento. Apunta aquí otra vez."
- "Creo que moviste la cámara. Vamos a mirar de nuevo."
- "¡Bien! Ese juguete ya no está."
- "Todavía veo otro juguete."
- "¡Área limpia!"

## 6. What the adult should observe

- The target highlight follows the real visible toy.
- The highlight disappears if the target is not currently visible.
- The mission does not complete when other toys remain visible.
- Moving the camera away asks for a rescan or blocks auto-collect.
- The diagnostics panel explains blocked auto-collect decisions.

## 7. If the app asks for rescan

- Tell the child: "Vamos a mirar el área otra vez."
- Point the camera back to the original cleanup area.
- Do not press manual confirmation unless the app repeatedly cannot decide.

## 8. If a toy is not detected

- Improve light and point the camera closer.
- Separate grouped toys.
- Try a larger or more colorful toy.
- Record the raw class, valid toy count, unknownToy count, and target
  confidence from diagnostics.

## 9. Successful demo criteria

- No false completion in the simple mission.
- No auto-collect caused only by camera movement.
- The child understands which toy to pick up.
- The adult can explain any rescan using the diagnostics panel.
- The app completes one simple real mission only after the area is actually
  clean.
