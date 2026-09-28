# Veredicto independiente de release: 2.4.1

Veredicto global: `PARTIAL`

La instrumentación de diagnóstico es útil en debug/profile y la ventana física
negativa aporta evidencia real de que no hubo progreso espontáneo durante ese
intervalo. No certifica el flujo principal de recogida, percepción, rendimiento
release, dispositivo objetivo ni distribución comercial.

Auditoría realizada el 2026-09-28 sobre:

- rama `qa/v2-4-0-physical-certification`;
- base `2267f4fa2586d613f12396bad045df8af5484657`;
- commit `1eb6c69dcd9153c39ec5cadf2e60458c696a3903`;
- tree `9423a289a478b3d6183dab12de405ddcacfc9109`;
- versión Flutter `2.4.1+8`.

El delta no modifica `lib/application`, `lib/domain`, `lib/perception` ni
`lib/infrastructure`. Agrega instrumentación de presentación, documentación y
una prueba del texto diagnóstico.

## Gates

| Gate | Evidencia | Resultado |
|---|---|---|
| Arquitectura | El delta no cambia percepción ni propietarios de eventos. En producción, `ToyCollected` y `CleanupCompleted` continúan construyéndose exclusivamente en `CleanupSessionService` | `PASS` |
| Estático | `dart format --output=none --set-exit-if-changed lib test tools`: 139 archivos, 0 cambios. `flutter analyze`: 0 issues. El diff del commit no presenta errores de whitespace | `PASS` |
| Unit/component | Suite completa reejecutada: 99/99. La prueba nueva valida el contenido de `buildDeveloperVisionSummary`, pero no la transición de modo infantil ni el tree-shaking release | `PASS` |
| Replay | Los replays automatizados existentes pasan y el benchmark desktop conserva presupuesto local. La captura 2.4.1 es metadata-only y no tiene píxeles, anotaciones ni ground truth para reproducir el fallo físico | `PARTIAL` |
| Adversarial | Sólo se ejecutó una ventana negativa no controlada. Pickup, oclusión, paneo/reidentificación controlados, múltiples objetos anotados, último objeto, habitación limpia y 10 sesiones quedaron `NOT_EXECUTED`; no existe matriz completa retenida | `BLOCKED` |
| Percepción | No existe `certification/dataset.json`, no hay splits anotados ni métricas de precision, recall, F1, AUC, ID switches, falsas recogidas o duplicados. El registro vigente además conserva un fallo observacional de recall físico | `BLOCKED` |
| Gameplay | No se ejecutó físicamente Home → Scan → pickup → siguiente objetivo → room clean → celebration. La separación Kid/Debug tiene un defecto de estado en debug/profile descrito abajo | `PARTIAL` |
| Rendimiento | El benchmark desktop del commit exacto pasó: wall p95 52.17 ms, análisis p95 32.00 ms, RSS +29.60 MB. El smoke profile con recorder dio inferencia p95 164.06 ms, FPS p50 3.99 y análisis Dart p95 102.84 ms; no es una medición release, sostenida ni comparable y carece de batería/termal completos | `BLOCKED` |
| Dispositivo | La ejecución fue en `SM-S942U`, no en el Galaxy S25 `SM-S93*` requerido. No se completó el procedimiento físico ni sus comprobaciones manuales | `BLOCKED` |
| Privacidad | La sesión declara `framesStored: false`; se retuvieron metadata y embeddings, no píxeles. La captura requiere `TOYVISION_CAPTURE` explícito y no se observó subida de frames. La evidencia derivada debe seguir tratándose como datos privados de prueba | `PASS` |
| Comercial/firma | Ambos APK usan `com.example.toyvision_realtime` y certificado `Android Debug`. El runtime/modelo Ultralytics conserva el bloqueo AGPL/Enterprise | `BLOCKED` |
| Revisión independiente | Esta auditoría no implementó el cambio. Los gates bloqueados y el defecto Kid/Debug impiden `PASS` | `BLOCKED` |

## Artefactos verificados

### APK profile

- Ruta: `build/app/outputs/flutter-apk/app-profile.apk`.
- Tamaño: `219221284` bytes.
- SHA-256:
  `D78E51E6E498ACFD7E3845B4406235CA14AE7BE07BC5694AF379EA58E32C49EB`.
- Package/version: `com.example.toyvision_realtime`, `2.4.1` (`8`).
- Firma: esquema v2, `C=US, O=Android, CN=Android Debug`.
- `lib/arm64-v8a/libapp.so`: `9962376` bytes; contiene `DEV frame:` y el
  texto del ajuste diagnóstico.

### APK release

- Ruta: `build/app/outputs/flutter-apk/app-release.apk`.
- Tamaño: `189200245` bytes.
- SHA-256:
  `947507FAA896DBCAFC9AF95C7BED800E6A64B140107015C36F540007F8125C18`.
- Package/version: `com.example.toyvision_realtime`, `2.4.1` (`8`).
- Firma: esquema v2, `C=US, O=Android, CN=Android Debug`.
- `lib/arm64-v8a/libapp.so`: `7078792` bytes; no contiene `DEV frame:` ni el
  texto del ajuste diagnóstico.

La comparación binaria respalda que `kReleaseMode` elimina la superficie de
diagnóstico del APK release. No convierte la firma debug ni el identificador de
ejemplo en una configuración publicable.

### Modelo

- Ruta: `assets/models/cleanup_items.tflite`.
- Tamaño: `62764989` bytes.
- SHA-256:
  `E30E3A03995A2F7E2FFB929D8BA26736EBBE2D275049A64FB35DF7A5F4657FEE`.
- El modelo embebido en ambos APK coincide en tamaño y SHA-256 con el archivo
  auditado. No hubo cambio de percepción en este commit.

## Evidencia física retenida

`certification/runs/v2_4_1_metadata_smoke/frames_final.jsonl` contiene 1009
frames desde `2026-09-28T15:16:16.224636Z` hasta
`2026-09-28T15:20:37.571653Z`: 261.347 segundos.

La lectura independiente del JSONL confirma:

- IDs creados: 1, 2, 3, 4 y 5;
- 126 transiciones `toyTemporarilyMissing` y 83 `toyReappeared`;
- cero `ToyCollected` y cero sesiones completadas;
- snapshot final de cinco elementos, tres tracks activos, dos missing, cero
  recogidos y tres candidatos inciertos;
- inferencia nativa p50/p95: 141.25/164.06 ms;
- FPS nativo p50/p05: 3.99/3.00;
- análisis Dart p95: 102.84 ms.

Esto demuestra que en esa ventana concreta no hubo recogida o completion
espontáneos. No demuestra tasa cero de falsas recogidas: no hubo pickup
controlado, ground truth, distractores anotados ni repetición de diez sesiones.

La memoria, temperatura y observación visual del overlay sólo están retenidas
como reporte del operador, no como una serie completa reproducible. Por ello no
se aceptan como certificación sostenida de rendimiento o UI.

## Revisión de `docs/v2.4.1_physical_smoke.md`

El reporte acierta al declarar `PARTIAL` y dice expresamente que no certifica
pickup, recall, identidad, habitación limpia ni release comercial. También
marca honestamente los escenarios no ejecutados, el dispositivo alterno y el
overhead del recorder.

La exclusión del diagnóstico en release está respaldada por `kReleaseMode` y
por la inspección binaria anterior. Sin embargo, estas dos afirmaciones del
reporte sobre debug/profile no están respaldadas por el código actual:

- “El overlay ... no aparece en modo infantil”.
- “Diagnóstico separado de Kid Mode: PASS”.

El toggle diagnóstico sólo se deshabilita mientras Kid Mode está activo. Si un
adulto desactiva Kid Mode, habilita `developerDebug` y luego reactiva Kid Mode,
`AppSettingsController.setKidMode` no restablece
`visionDisplayModeProvider`. `CleanupScreen` decide mostrar el overlay usando
solamente `developerVisionAvailable` y `visionMode`, sin consultar
`kidModeEnabled`. En debug/profile, el overlay puede por tanto persistir sobre
la superficie infantil. El APK release no está afectado porque
`developerVisionAvailable` es constante `false` allí.

El reporte debe tratar la separación Kid/Debug como `PARTIAL` hasta corregir y
probar esa transición. La ventana negativa puede conservar `PASS` sólo con su
alcance explícito de 1009 frames; no equivale a aprobar falsa recogida en el
producto.

## Bloqueadores y riesgos residuales

- No hay dataset/corpus certificable ni métricas de aceptación 2.4.1.
- No se ejecutó una recogida física real ni la continuación/completion.
- Cero de diez sesiones completas requeridas fueron ejecutadas.
- El dispositivo alterno no satisface el gate Galaxy S25.
- El perfil con recorder es lento y no caracteriza el APK release.
- La separación Kid/Debug falla en una transición válida de estado para
  debug/profile y carece de test de widget/release dedicado.
- La evidencia metadata-only no puede validar cajas, identidad o ground truth
  visual.
- Licencia comercial, application ID y firma de producción siguen bloqueados.
- No existe una atestación reproducible que vincule formalmente los binarios
  locales al commit, aunque versión, hashes y modelo embebido fueron verificados.

## Condiciones exactas para `PASS`

1. Impedir que `developerDebug` sobreviva al activar Kid Mode y agregar una
   prueba que cubra desactivar Kid Mode → activar diagnóstico → reactivar Kid
   Mode → abrir limpieza sin overlay; conservar además la prueba de exclusión
   en release.
2. Corregir las dos afirmaciones Kid/Debug del smoke o regenerar el reporte con
   evidencia del fix exacto.
3. Ejecutar en el Galaxy S25 objetivo pickup estable, oclusión, paneo y
   reidentificación controlados, múltiples objetos anotados y el flujo hasta
   una única celebración, sin recogidas/completions prohibidos.
4. Completar diez sesiones físicas consecutivas y retener eventos, identidades,
   progreso SQLite y resultados manuales.
5. Con consentimiento, crear `certification/dataset.json` con splits aislados,
   píxeles y anotaciones completas; superar precision ≥ .90, recall ≥ .85,
   F1 ≥ .87, AUCs requeridos y cero falsas recogidas, duplicados e ID switches.
6. Perfilar 10–15 minutos el APK release exacto sin recorder: p50/p95/p99,
   FPS/drops, CPU/GPU, RSS, batería y estados térmicos, con presupuesto aprobado.
7. Resolver licencia del modelo/runtime/assets, application ID y firma de
   producción; reconstruir, hashear y volver a auditar el artefacto final.

## Comandos y comprobaciones reejecutados

```text
dart format --output=none --set-exit-if-changed lib test tools
flutter analyze
flutter test -r expanded
git diff --check 2267f4f..1eb6c69
aapt dump badging <profile/release APK>
apksigner verify --verbose --print-certs <profile/release APK>
SHA-256 de APKs, modelo y modelo embebido
inspección de lib/arm64-v8a/libapp.so en ambos APKs
lectura y agregación de frames_final.jsonl
origen de ToyCollected/CleanupCompleted en lib/
```
