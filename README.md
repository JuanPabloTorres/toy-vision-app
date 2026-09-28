# Toy Vision

Versión actual: `2.4.1+8`. El flujo de ramas y versionado obligatorio está
documentado en [`docs/development_workflow.md`](docs/development_workflow.md).

Aplicación Flutter local-first que ayuda a un niño a recoger juguetes, ropa y
objetos sueltos mediante
percepción híbrida on-device. El flujo infantil es deliberadamente corto:
`Home → Scan/Cleanup → Celebration`; Settings queda separado para adultos.

## Pipeline

```text
CameraX + TFLite YOLO (propuestas, no verdad absoluta)
  + IMU Android (giroscopio, aceleración y rotation vector)
  → frame adapter con píxeles reales
  → propuestas open-set por contraste/textura/geometría
  → embeddings visuales de escena y crops
  → fusión numérica de evidencia
  → tracking (IoU + centro + tamaño + cosine similarity)
  → estabilidad/oclusiones/movimiento de cámara
  → fusión física + background reveal + cobertura direccional
  → verificación temporal de desaparición
  → RoomWorldModel
  → CleanupSessionService y eventos de dominio
  → caso de uso de finalización + transacción SQLite
  → UI, Tobi 3D, Rive, Lottie y audio después del commit
```

Las etiquetas de YOLO se conservan únicamente como diagnóstico. Ninguna
decisión de aceptación, tracking, recogida o finalización usa nombres,
keywords, regex o listas de clases.

## Capas

| Ruta | Responsabilidad |
|---|---|
| `lib/domain/` | Entidades y reglas puras de escena, juguetes y cleanup |
| `lib/perception/` | embeddings, propuestas, fusión, tracking y desaparición |
| `lib/application/` | casos de uso, estado de sesión y bus de eventos |
| `lib/infrastructure/` | cámara/YOLO, TFLite, audio, persistencia y salud del dispositivo |
| `lib/presentation/` | Home, Scan/Cleanup, Celebration, Settings y feedback visual |
| `lib/core/` | matemática y política adaptativa compartidas |

La regla de dependencias objetivo y la clasificación de la migración están en
[`docs/sow_architecture_audit.md`](docs/sow_architecture_audit.md). La evidencia
de implementación y los límites verificados están en
[`docs/sow_implementation_evidence.md`](docs/sow_implementation_evidence.md).

## Operación local

El detector requerido está incluido en `assets/models/cleanup_items.tflite`;
no existe
descarga ni fallback remoto. Android solicita `CAMERA` para la función visible
y declara `INTERNET` únicamente porque el visor 3D sirve el glTF incluido sobre
loopback (`127.0.0.1`); no solicita audio ni almacenamiento. Los frames,
embeddings y cajas no se persisten; SQLite guarda únicamente progreso seguro
(sesiones, habitaciones, ledger de estrellas, rachas y logros), mientras
SharedPreferences queda limitado a ajustes de UI. La única excepción es una build de
certificación que exige habilitar explícitamente captura y, por separado,
retención temporal de píxeles.

```powershell
C:\DevTools\flutter\bin\flutter.bat pub get
C:\DevTools\flutter\bin\flutter.bat analyze
C:\DevTools\flutter\bin\flutter.bat test

$env:Path = 'C:\DevTools\flutter\bin;C:\DevTools\flutter\bin\cache\dart-sdk\bin;' + $env:Path
C:\DevTools\flutter\bin\flutter.bat build apk --release
```

Rive Native necesita que `dart` esté disponible en `PATH` durante la tarea
Gradle de setup.

## Privacidad y licencias

- Inferencia y feedback funcionan sin backend ni permiso de Internet.
- No se guarda imagen, audio, identidad personal ni embedding.
- El plugin/modelo Ultralytics usado por este repositorio está sujeto a AGPL;
  una distribución comercial cerrada requiere licencia Enterprise o sustituir
  ese detector por una alternativa compatible.

## Validación

Los tests incluyen replay de cámara con movimiento, reaparición, desaparición,
open-set sin cajas YOLO, prevención de doble conteo, persistencia privada,
política térmica/batería, integridad de assets y flujo UI. La validación física
en Galaxy S25 sigue siendo obligatoria antes de declarar release comercial.
El protocolo reproducible, el esquema de anotación y los comandos de corpus
están en [`docs/certification_harness.md`](docs/certification_harness.md).
La arquitectura de fusión, sus fallbacks y el límite actual de ARCore están en
[`docs/sensor_fusion_architecture.md`](docs/sensor_fusion_architecture.md).
