# Veredicto independiente de release: 2.4.0

Veredicto: `PARTIAL`

La detección ampliada es integrable como trabajo de desarrollo, pero no está
certificada para release ni demuestra todavía que ropa, objetos domésticos y
múltiples elementos se detecten y recojan sin falsos positivos en una escena
real. La auditoría se ejecutó el 2026-09-27 sobre la rama
`feature/collectible-item-detection`, commit inmutable
`a1d2d4067842c19e7ded021860d4a0c6236f9d9c` y tree
`291644138c893ce7821ddabb444b94bb88621645`. El delta posterior al commit de
código `fc878ce584753e391f753970425eeede68b4b025` es exclusivamente documental.

| Gate | Evidencia | Resultado |
|---|---|---|
| Arquitectura | `ToyCollected` y `CleanupCompleted` siguen originándose en producción sólo en `CleanupSessionService`; el cambio de modelo, umbral y memoria temporal no crea otro propietario de eventos | `PASS` |
| Estático | `dart format --output=none --set-exit-if-changed lib test tools`: 138 archivos, 0 cambios; `flutter analyze`: 0 issues; `git diff --check`: limpio | `PASS` |
| Unit/component | Tests enfocados: 17/17; suite completa: 98/98. Incluye tres candidatos pequeños con jitter, propuesta 0.14 que permanece incierta, invariantes de movimiento/oclusiones y origen de progreso | `PASS` |
| Replay | Los replays sintéticos existentes pasan, pero ninguno reproduce una captura real con el nuevo modelo de 30 clases ni el fallo original de multiobjeto/ropa | `PARTIAL` |
| Adversarial | La matriz ya distingue positivos sueltos/en el área de limpieza de negativos puestos, sostenidos o almacenados, además de personas, mobiliario, instalaciones y suelo vacío. No existe ejecución retenida de esa matriz con este artefacto, incluyendo objetos similares/adyacentes, cajas anidadas y desaparición/reaparición | `BLOCKED` |
| Percepción | `certification/dataset.json` no existe; el validador termina con `PathNotFoundException`. No hay precision, recall, F1, hard-negative FP, ID switches, false collections o duplicate collections medidos sobre train/validation/test real | `BLOCKED` |
| Gameplay | Widgets, controlador y flujo sintético pasan. No hay recorrido físico Home → Scan de ropa/múltiples objetos → recogida → siguiente objetivo → Celebration | `PARTIAL` |
| Rendimiento | Replay local de 40 frames: wall p95 75.62 ms, análisis p95 50.14 ms, RSS +28.26 MB; no existe perfil del APK 2.4.0 en dispositivo físico ni medición sostenida de FPS, temperatura o batería | `PARTIAL` |
| Dispositivo | `adb devices -l` no devuelve ningún dispositivo; no se ejecutó `certify_galaxy_s25.ps1` ni la inferencia CameraX/TFLite real del APK candidato | `BLOCKED` |
| Privacidad | El modelo es local y la captura de evidencia sigue desactivada salvo flags explícitos; el manifest no incorpora permisos de micrófono o almacenamiento. Los permisos de red/foreground heredados continúan como riesgo de dependencias, sin evidencia de subida de frames desde la app | `PASS` |
| Comercial/firma | Modelo/runtime Ultralytics AGPL/Enterprise sin resolver, `applicationId` de ejemplo y APK release firmado por `C=US, O=Android, CN=Android Debug` | `BLOCKED` |
| Revisión independiente | Esta auditoría no implementó el cambio; los gates bloqueados impiden emitir `PASS` | `BLOCKED` |

## Fuente y artefactos exactos

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- Versión APK: `2.4.0`, versionCode `7`.
- Tamaño APK: `189282337` bytes.
- SHA-256 APK:
  `85771A2F6CDB7E798276284FD06405FBD05392B7E35E2C2C0A1E8DA3753DC975`.
- Firma APK: Android Debug, esquema v2.
- Modelo: `assets/models/cleanup_items.tflite`.
- Tamaño modelo: `62764989` bytes.
- SHA-256 modelo:
  `E30E3A03995A2F7E2FFB929D8BA26736EBBE2D275049A64FB35DF7A5F4657FEE`.
- El modelo embebido dentro del APK tiene exactamente el mismo tamaño y
  SHA-256 que el archivo auditado.

## Hallazgos sobre multiobjeto y ropa

- El artefacto declara 30 prompts: conserva los 20 de juguetes y agrega ropa,
  zapatos, libro, mochila, botella, caja y control remoto. Esos nombres son
  diagnósticos; la lógica de aceptación permanece numérica y no contiene
  keywords o regex.
- El umbral nativo baja de 0.25 a 0.12. La prueba nueva demuestra que una
  propuesta 0.14, incluso persistente y con objectness fuerte, queda incierta y
  no se convierte directamente en juguete/objeto confirmado.
- La prueba de tres elementos verifica la fusión con candidatos construidos en
  memoria. No ejecuta el TFLite, CameraX, NMS, transformaciones de coordenadas,
  tracking de identidades ni recogida física de tres objetos reales.
- Un smoke offline del modelo produce propuestas adicionales y confirma que el
  vocabulario ampliado está presente. Esto no establece recall, precision ni
  seguridad de colección. Las propuestas de baja confianza todavía necesitan
  atravesar fusión, tracking y verificación de desaparición.
- La tolerancia de jitter aumenta hasta 0.019 normalizado y acepta variación de
  tamaño hasta 0.75. Falta medir su efecto en objetos pequeños adyacentes,
  visualmente similares o cruzados, donde podría aumentar asociaciones
  incorrectas o duplicadas.
- El commit documental `a1d2d40` resuelve la contradicción de alcance: ropa,
  zapatos, libros, mochilas, botellas, cajas y controles sueltos en el área son
  positivos; los mismos tipos puestos, sostenidos o almacenados son negativos.
  La taxonomía es coherente, aunque todavía no cuenta con ejecución de corpus.

## Invariantes de falsa recogida

La rama preserva las barreras estructurales: propuesta no equivale a objeto
confirmado; ausencia, oclusión, movimiento y pérdida de track no publican
`ToyCollected`; la recogida continúa exigiendo identidad del snapshot,
historial estable, interacción, región reobservada, ventana de desaparición y
ausencia de reidentificación plausible. La suite automatizada pasa estas reglas.

Eso no permite afirmar cero falsas recogidas con el nuevo detector. Al bajar el
umbral entran más propuestas y la tolerancia temporal es más amplia. Sólo el
corpus real y la matriz adversarial pueden demostrar que ninguna propuesta
incorrecta completa toda la cadena de confirmación y desaparición.

## Provenance y riesgos residuales

- El hash, metadata de 30 clases y binarios exportados son coherentes, pero
  `tools/toy_model_export/export_run312.log` pertenece al modelo anterior:
  termina copiando `toys.tflite` y registra un commit CLIP diferente al pin
  actual. Falta un log de exportación retenido que corresponda exactamente al
  modelo 2.4.0.
- La especificación ya distingue ropa suelta de ropa puesta, sostenida o
  almacenada, pero no hay evidencia ejecutada de que el modelo y la fusión
  distingan esos contextos ni muebles visualmente parecidos.
- No hay límites medidos de cajas duplicadas, ID switches o consolidación de
  cajas anidadas para el nuevo umbral.
- Las limitaciones previas de ARCore/Depth, corpus, dispositivo, licencias y
  firma productiva permanecen sin cambios.

## Condiciones exactas para `PASS`

1. Crear `certification/dataset.json` con splits independientes y anotación
   completa del nuevo alcance: juguetes, ropa suelta, ropa puesta/fondo,
   objetos domésticos, persona, muebles, objetos pequeños/adyacentes/similares,
   oclusión, blur, baja luz, paneo y desaparición/reaparición.
2. Superar precision ≥ .90, recall ≥ .85, F1 ≥ .87, AUCs requeridos y
   cero ID switches, falsas recogidas, duplicados y completions prohibidos en el
   test retenido.
3. Ejecutar el flujo físico completo y la matriz adversarial con el APK exacto
   en el dispositivo objetivo, incluyendo perfil sostenido y validación manual
   de UI, audio, animación y feedback.
4. Retener un log reproducible del export exacto y reconciliar versiones,
   commit CLIP, metadata, binarios y hash.
5. Resolver licencia comercial/modelo/assets, `applicationId` y firma de
   producción; reconstruir y volver a auditar el APK resultante.

## Comandos reejecutados

```text
dart format --output=none --set-exit-if-changed lib test tools
flutter analyze
flutter test test/perception/candidate_fusion_test.dart test/infrastructure/yolo_model_config_test.dart test/integration/safety_regression_test.dart test/integration/multi_toy_gameplay_test.dart -r expanded
flutter test -r expanded
flutter pub run tools/toyvision_certify.dart validate certification/dataset.json
adb devices -l
```
