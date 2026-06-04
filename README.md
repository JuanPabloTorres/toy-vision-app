# ToyVision — Toy Cleanup YOLO

## Versionado

- Versión actual: `1.0.0`
- Control de versión: SemVer en `pubspec.yaml` con formato `MAJOR.MINOR.PATCH+BUILD`.
  - `MAJOR.MINOR.PATCH` = versión de producto (ejemplo: `1.0.0`).
  - `BUILD` = número interno de compilación para stores (ejemplo: `+1`, `+2`, ...).

App móvil Flutter que ayuda a un niño a recoger sus juguetes. Detecta objetos
del piso en vivo con YOLO on-device, los cuenta, y muestra un mensaje claro:
*"Veo 4 juguetes. Vamos uno por uno."* → *"Muy bien. Ahora quedan 3."* →
*"¡Excelente! Ya no veo juguetes en el piso."*

**Local-first, privacy-first**: la inferencia corre 100% en el teléfono.
Ningún frame se sube a un servidor; no hay backend.

## Arquitectura (Phase 6.0)

```text
Flutter app (lib/)
  └── ToyCleanupCameraScreen
        └── YOLOView (ultralytics_yolo plugin)
              ├── owns camera nativa + inferencia + overlay de cajas
              └── onResult → ToyCleanupController
                    └── YoloDetectionMapper (COCO → registry, conservador)
                          └── ToyDetectionRules (confidence / box gates)
                                └── ToyTrackingEngine (IoU, identidad cross-frame)
                                      └── ToyCountingService (min 3 frames estable)
                                            └── CleanupGuidanceService (copy Mateo)
                                                  └── LiveDetectionState → UI
```

El plugin oficial de Ultralytics envuelve la cámara nativa + el runtime YOLO
(TFLite en Android, CoreML en iOS). El modelo por defecto es `yolo26n` (COCO
80 clases, ~6 MB); se descarga la **primera vez** que se abre la app y
queda cacheado para siempre.

## Vocabulario (COCO 80 → juguete)

El modelo `yolo26n` no fue entrenado en juguetes específicos; conoce las 80
categorías COCO. El **mapper** filtra y reinterpreta de forma conservadora:

| COCO label | Mapped registry | Comportamiento |
|---|---|---|
| `teddy bear` | `stuffed_animal` | Cuenta automático (Peluche) |
| `sports ball` | `ball` | Cuenta automático (Pelota) |
| `car` / `truck` / `train` | `toy_car` / `toy_truck` / `toy_train` | Cuenta (asumimos miniatura en cuarto de niño) |
| `airplane` / `boat` / `bicycle` / `motorcycle` / `bus` | `toy_vehicle` | Cuenta (vehículo de juguete) |
| `kite` / `frisbee` / `skateboard` | `toy_outdoor` | Cuenta (con confidence más baja) |
| `book` | `book` | Cuenta (puede ser libro o juguete) |
| `backpack` / `suitcase` / `scissors` | `object` | Cuenta (revisar manualmente) |
| `person`, `chair`, `couch`, `tv`, etc. | — | **Descartado en el mapper** (nunca llega al pipeline) |
| `dog`, `cat`, `bird`, etc. | — | Descartado (animales reales) |
| Cualquier otro label COCO | — | Descartado |

**Limitación conocida**: COCO no tiene `doll`, `lego`, `action figure`,
`puzzle`, `board game`. Esos juguetes hoy no se detectan. El plan a futuro
(Phase 7) es bundlear un `.tflite` específico de juguetes (Roboflow o
fine-tune propio); el mapper está diseñado para que ese cambio sea aislado.

## Privacidad

- Inferencia **100% en el dispositivo**. El plugin lee frames de cámara,
  los pasa al runtime nativo, dibuja cajas y los descarta. Nada se escribe a
  disco.
- Solo permiso `CAMERA` + `INTERNET` (este último únicamente para descargar
  el modelo la primera vez ~6 MB).
- Sin audio, sin reconocimiento facial, sin person-ID, sin analytics, sin
  cuenta de usuario.
- El historial de scans (`SavedScanSummary`) guarda solo conteos y
  timestamps — nunca imágenes.

## Empezar

```powershell
flutter pub get
flutter analyze
flutter test
flutter run        # con un Android o iOS conectado
```

## Licencias

| Componente | Licencia | Notas |
|---|---|---|
| Este repo | Privado / personal | No publicado |
| `ultralytics_yolo` plugin | **AGPL-3.0** | OK para prototipo personal |
| Modelo `yolo26n` (Ultralytics) | **AGPL-3.0** | OK para prototipo personal |
| Flutter / Riverpod / permission_handler | BSD / MIT | Sin restricciones |

> **Importante**: la AGPL-3.0 de Ultralytics aplica al plugin y al modelo
> entrenado. Para distribución comercial cerrada o publicación pública es
> necesario contratar una **Ultralytics Enterprise License**, o reemplazar
> el detector por una alternativa con licencia más permisiva (Apache,
> MIT). El uso actual — prototipo personal local, sin distribución — no
> requiere ninguna acción.

## Trabajar en este repo

- [CLAUDE.md](CLAUDE.md) — instrucciones para Claude Code (entry point).
- [.toyvision/](.toyvision/) — gobernanza: principios de arquitectura,
  agentes, skills, manual-QA.
- [.toyvision/archive/](.toyvision/archive/) — código fuera de runtime
  (TFLite, ML Kit, servidor Python). Preservado por historia, no
  compilado.

## Estructura

| Path | Propósito |
|---|---|
| `lib/main.dart` | Entry: `runApp(ProviderScope(ToyVisionApp))` |
| `lib/app/` | MaterialApp + tema dark + router |
| `lib/camera/screens/toy_cleanup_camera_screen.dart` | Único screen vivo: YOLOView + UI |
| `lib/camera/controllers/toy_cleanup_controller.dart` | Orquestador del pipeline |
| `lib/detection/yolo/` | Config del modelo + mapper COCO→registry |
| `lib/business/` | Reglas, registry, counting, **guidance**, review |
| `lib/tracking/` | IoU + identidad cross-frame |
| `lib/ui/` | Componentes, panels, overlays, screens |
| `test/` | Unit + widget + scenario (122 tests) |

## Notas técnicas

- **`minSdk = 24`** en Android (requisito de `ultralytics_yolo` v0.4.2 +
  `permission_handler` v12).
- El plugin maneja la rotación de cámara internamente; usamos
  `result.normalizedBox` directo (sin conversión manual).
- `YOLOView` dibuja su propio overlay de cajas nativamente — por eso el
  archivo `DetectionOverlayPainter` queda dormido (no se monta). Se
  reactiva cuando tengamos UI custom de coloreado por status de review.
