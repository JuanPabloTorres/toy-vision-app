# Evidencia de implementación del SOW Toy Vision

Fecha: 2026-09-27

Estado: **PARTIAL**.

La arquitectura, el flujo infantil y los mecanismos de seguridad están
implementados y probados. La aplicación release está instalada en un Samsung
SM-S942U (Galaxy S26, Android 17/API 37), pero no se cumplen todavía los gates
de PASS: el dispositivo exigido era Galaxy S25, no existe un corpus real
etiquetado train/validation/test, la escena física mostró recall incompleto, no
se completó físicamente una sesión estable hasta celebración y la licencia
comercial de Ultralytics sigue sin resolverse.

## Arquitectura final

```text
presentation -> application -> domain
      |                |
      +------ infrastructure adapters

Camera / native YOLO proposals + pixels
  -> VisualFrameAnalyzer
     -> GridObjectProposalGenerator
     -> PerceptualEmbeddingExtractor (identity, non-semantic)
     -> frozen spatial scene signature
  -> ToyCandidateFusion
  -> ToyTracker / TrackAssociator
  -> SceneStabilityService / OcclusionReasoner
  -> DisappearanceVerifier
  -> RoomWorldModel
  -> CleanupSessionService / CompletionEvaluator / CollectedObjectMemory
  -> CompleteCleanupSessionUseCase
  -> atomic SQLite progress transaction
  -> committed CleanupEvent bus
  -> Home / Prepare / Scan / Cleanup / Verify / Celebration
```

El dominio no importa Flutter ni plugins. `CleanupSessionService` es el único
productor de `ToyCollected`; la UI solo representa estado y envía intenciones.
Los labels del detector se conservan exclusivamente para diagnóstico.

El progreso infantil ya no se deriva desde widgets ni se guarda en
SharedPreferences. `SqliteProgressRepository` registra atómicamente sesión,
progreso de habitación, ledger de estrellas, racha y logros. La política de
recompensas/rachas es dominio puro; el ID de sesión vuelve idempotente cualquier
reintento. El controlador difiere `RoomCleanConfirmed` y `CleanupCompleted`
hasta que el commit termina, por lo que un fallo de persistencia no dispara la
celebración. El historial legado se importa una sola vez y la clave anterior se
elimina únicamente después de completar la migración.

## Refactor visual y funcional

- Flujo final: `Splash -> Onboarding -> Home -> Prepare -> Scan -> Confirm ->
  Cleanup -> Verify empty -> Celebration -> Home`.
- Home infantil con Tobi, un CTA, estrellas, racha, última sesión, Settings y
  About; se eliminaron dashboard, tabs, challenges, review y targets manuales.
- Una sola pantalla de cámara cambia de fase sin convertir detecciones en
  eventos de dominio.
- Un objetivo activo usa halo brillante; los demás son suaves. No se muestran
  labels ni confidencias nativas de YOLO.
- Settings y progreso persisten localmente. Cámara, feedback y animación se
  coordinan por eventos.
- El glTF primitivo y el `.riv` genérico de cofre/monedas se deshabilitaron en
  el flujo infantil después de revisión física. Se usa Tobi 2D y Lottie local
  acotado; los adapters siguen desacoplados para assets de producción válidos.

La clasificación KEEP/REFACTOR/ADD/DELETE está en
`docs/concept_refactor_audit.md` y la auditoría SOW previa en
`docs/sow_architecture_audit.md`.

## Core de percepción implementado

- El adaptador exige los píxeles reales del frame y conserva propuestas
  numéricas sin reglas por nombres.
- La fusión usa confianza, persistencia, estabilidad espacial, soporte de
  propuesta y contexto de escena. La evidencia fusionada puede confirmar una
  detección moderada estable sin rebajar el threshold global.
- La memoria temporal se recupera después de un paneo, pero exige tres
  observaciones estacionarias y no confirma movimiento continuo.
- El tracker bloquea hijacking por regiones open-set, deriva acumulada de
  escala y contaminación de la huella con candidatos no confirmados.
- La firma de habitación es espacial y firmada; se actualiza durante el scan,
  se congela al crear el snapshot y mantiene enmascaradas las regiones
  iniciales durante toda la sesión.
- Desaparición exige track confirmado, interacción observada, escena anclada,
  región reobservada, ausencia mínima de 10 frames y 2.5 segundos, ausencia de
  oclusión y ausencia de candidatos de reidentificación.
- La finalización exige una segunda ventana vacía de al menos 2 segundos y
  tres frames. La memoria de recogidos evita conteo duplicado.

Limitación explícita: `perceptual-v1-non-semantic` es un descriptor de color,
gradientes y estructura; no es un embedding semántico toy/non-toy. Las
propuestas puramente open-set se rastrean como inciertas, pero no se promueven
a juguete confirmado sin evidencia semántica. Por tanto, la promesa open-set
completa del SOW sigue pendiente de un modelo on-device validado con corpus.

## Hallazgos físicos y correcciones

Las capturas instrumentadas fueron metadata-only; no se persistieron frames de
cámara. Las screenshots en `certification/` son evidencia de desarrollo
explícita y esa carpeta está ignorada por git.

| Ejecución | Evidencia | Resultado / corrección |
|---|---|---|
| `geometry_fusion_physical` | 104 frames | La confianza fusionada alcanzó 0.76 pero un veto por frame bloqueaba el snapshot. Se eliminó el doble veto sin cambiar thresholds. |
| `fused_gate_physical` | 364 frames | La cámara en movimiento envenenaba para siempre el ancla temporal del candidato. Se implementó recuperación local con ventana estacionaria. |
| `temporal_recovery_physical` | 413 frames | Creó snapshot y emitió 1 colección, pero el peluche reapareció: falsa colección crítica. Se encontró deriva de identidad y ausencia de solo 1.506 s. |
| `false_collection_guard_physical` | 309 frames | La nueva espera evitó dos desapariciones, pero otra región se contó tras paneo porque el descriptor global daba 0.989 a vistas distintas. |
| `scene_anchor_guard_physical` | 308 frames analizados | Con firma espacial congelada: 0 colecciones durante paneo/reencuadre. El oso desapareció, pero el ancla cayó a 0.467 y el sistema bloqueó correctamente el conteo. |

La última escena física mostró oso, vehículo, Mickey, un juguete pequeño, ropa
y calzado. La app no marcó ropa/calzado, pero congeló solo 2 objetivos cuando
había al menos 3 juguetes visibles; esto es evidencia de recall incompleto y
prohíbe PASS. Tampoco se obtuvo `CleanupCompleted` físico porque el encuadre no
regresó al ancla después de retirar el objetivo.

## Validación final

| Validación | Resultado |
|---|---|
| `dart format lib test tools` | PASS |
| `flutter analyze` | PASS, 0 issues |
| `flutter test -r compact` | PASS, 90 tests |
| `flutter build apk --debug` | PASS; integración Android de SQLite compilada |
| Replay local, 40 frames | wall p95 67.61 ms; análisis p95 42.48 ms; RSS +44.41 MB |
| APK release sin captura | PASS, 179,323,637 bytes |
| Instalación release en SM-S942U | PASS |
| Cámara, modelo TFLite y UI en SM-S942U | PASS parcial: inferencia y snapshots observados |
| Paneo sin falsa colección en build final instrumentada | PASS: 0 `ToyCollected` |
| Sesión física completa hasta celebración | NO DEMOSTRADA |
| Corpus real retenido train/validation/test | NO DISPONIBLE |

SHA-256 de `build/app/outputs/flutter-apk/app-release.apk`:
`E0D33290640B1C968E3EF3A11900971D0F91F97AA13C106D8D87EFB5095367CD`.

El manifest release contiene `CAMERA`, `INTERNET`, `ACCESS_NETWORK_STATE`,
servicios foreground/data-sync, wakelock y receive-boot-completed; no contiene
permisos de audio ni almacenamiento. `INTERNET` procede de la integración local
3D/plugin y debe revisarse si se exige operación estrictamente sin red.

El benchmark anterior es una regresión local Windows, no una medición del
Galaxy. No se obtuvieron p50/p95/p99 end-to-end, temperatura, batería, CPU/GPU
ni estabilidad prolongada válidos para Galaxy S25.

## Bloqueos para PASS

1. El dispositivo conectado es SM-S942U/Galaxy S26; el gate contractual exige
   Galaxy S25 (`SM-S93*`).
2. Falta el corpus real, etiquetado y separado en train/validation/test; no hay
   precision, recall, F1, ID switches, false collections ni duplicate
   collections reportables sobre test retenido.
3. El detector físico mostró recall incompleto y agrupación de objetos. Hace
   falta el YOLO custom entrenado con juguetes y hard negatives definido por el
   SOW, o un `ObjectDetector` alternativo equivalente.
4. El embedding actual no está validado para toy/non-toy ni identidad física;
   sigue pendiente su evaluación o sustitución por un modelo ligero on-device.
5. Ultralytics Flutter/runtime/model siguen bajo riesgo AGPL/Enterprise para
   distribución comercial cerrada; `ObjectDetector` permanece desacoplado para
   sustitución.
6. No existe evidencia física completa de `Camera -> proposals -> embeddings
   -> fusion -> tracking -> disappearance -> ToyCollected -> completion ->
   feedback` con encuadre estable.
7. Audio, haptics, asset Rive de producción, glTF de producción y estabilidad
   térmica prolongada no están certificados físicamente.

El harness y los comandos de corpus están en `docs/certification_harness.md`;
la matriz física está en `docs/real_device_validation.md` y la auditoría de
licencia en `docs/ultralytics_dependency_audit.md`.
