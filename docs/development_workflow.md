# Flujo obligatorio de cambios

Este repositorio usa `main` como rama de integración. Cada instrucción que
produzca cambios se implementa en una rama específica y recibe una versión
SemVer propia antes de fusionarse.

## Antes de modificar

1. Leer `AGENTS.md`, `.codex/README.md` y la documentación o skill enrutada.
2. Inspeccionar `git status`, la rama actual y el código afectado.
3. Clasificar el trabajo y crear una rama desde `main`:
   - `feature/<nombre>` para funcionalidad nueva.
   - `fix/<nombre>` o `bugfix/<nombre>` para defectos.
   - `dev/<nombre>` para trabajo interno de desarrollo.
   - `qa/<nombre>` para pruebas o evidencia.
   - `release/<version>` para consolidar una entrega.
   - `docs/<nombre>` o `chore/<nombre>` para documentación o mantenimiento.

## Versionado

Se actualiza `version:` en `pubspec.yaml` una vez por cada solicitud terminada:

- `MAJOR`: cambio incompatible o migración obligatoria.
- `MINOR`: funcionalidad nueva compatible.
- `PATCH`: corrección compatible.
- El número después de `+` siempre aumenta para que Android/iOS acepten el
  artefacto como una build nueva.

El cambio se registra también en `CHANGELOG.md`. Los ajustes intermedios dentro
de la misma rama forman parte de una sola versión; no se incrementa la versión
por cada archivo o commit técnico.

## Validación y fusión

1. Ejecutar formato, análisis, tests y las puertas relevantes definidas en
   `.codex/QUALITY_GATES.md`.
2. Revisar que no se incluyan secretos, datos privados de cámara o artefactos
   locales.
3. Documentar gates bloqueados. Una compilación correcta no equivale a release
   comercial aprobado.
4. Fusionar la rama validada en `main` y crear la etiqueta `vMAJOR.MINOR.PATCH`.
5. Publicar `main`, la rama de cambio y la etiqueta sin `force push`.

La rama histórica `master` se conserva como referencia hasta que su retiro se
solicite y se confirme por separado.
