# Veredicto de integración: 2.2.0

Veredicto independiente: `PARTIAL`

La integración técnica de sensor fusion es auditable, pero no constituye una
certificación del core físico ni un release comercial. La reauditoría se
ejecutó el 2026-09-27 sobre el commit inmutable
`9f6a508b2cf3f141ad1dc9c20ead6e41cd32c971` (tree
`bb41eacc7f604afff3a39dd0579354de3c9a6f29`).

| Gate | Evidencia | Resultado |
|---|---|---|
| Arquitectura | `ToyCollected` y `CleanupCompleted` sólo se originan en `CleanupSessionService`; sensores y fusión no publican eventos de dominio | `PASS` |
| Estático | 136 archivos sin cambios de formato; `flutter analyze`: 0 issues; diff-check limpio | `PASS` |
| Unit/component | `flutter test -r expanded`: 95/95; cubre movimiento alto, background reveal, cobertura, candidato open-set e invariantes | `PASS` |
| Replay | Replays sintéticos pasan; falta replay físico del fallo original con IMU y cobertura | `PARTIAL` |
| Adversarial/percepción | Matriz preparada, pero no ejecutada; no existe `certification/dataset.json` real y el recall físico previo está documentado como insuficiente | `BLOCKED` |
| Gameplay | UI/controlador y smoke de cámara pasan; falta ejecutar pickup → siguiente objetivo → barrido → persistencia → celebración | `PARTIAL` |
| Rendimiento/dispositivo | Replay local dentro del presupuesto; sin perfil físico sostenido y el smoke fue en SM-S942U, no en el Galaxy S25 requerido | `PARTIAL` / `BLOCKED` |
| Privacidad | Captura de frames es opt-in; sin permisos de micrófono/storage ni subida desde la app | `PASS` |
| Comercial/firma | Licencia Ultralytics, inventario de assets, `applicationId` productivo y firma de producción siguen sin resolver | `BLOCKED` |
| Revisión independiente | Reauditoría exacta completada; los gates bloqueados impiden `PASS` | `BLOCKED` |

## Artefacto verificable

- APK: `build/app/outputs/flutter-apk/app-release.apk`.
- Tamaño: `187920688` bytes.
- SHA-256: `3326C358F4A827C41AAD14D27899D6413503F4103B6ACF615E41C8604F70E0E1`.
- Firma: `C=US, O=Android, CN=Android Debug`.
- Modelo: `assets/models/toys.tflite`.
- SHA-256 del modelo:
  `B21CB8ED24EADBCE951C462E126A65D5D328EA0D8C27DEFF68C17AC38B018A91`.

El smoke alterno confirmó cámara y registro a 20 ms de rotation vector,
aceleración lineal y giroscopio. No sustituye el recorrido físico requerido.

## Alcance y bloqueos preservados

- ARCore pose y Depth son contratos opcionales, no proveedores implementados.
  La cámara actual pertenece a CameraX mediante `ultralytics_yolo`; integrar
  ARCore Shared Camera exige migrar la propiedad a Camera2/ARCore.
- `BackgroundRevealDetector` compara descriptores perceptuales del ROI; no es
  optical flow ni feature tracking geométrico.
- Los picos IMU se retienen 750 ms, las muestras obsoletas se descartan, los
  candidatos open-set bloquean completion y los sensores paran al completar.
  Estas mitigaciones pasan revisión estática/unitaria, pero aún requieren E2E
  físico.

## Condiciones para alcanzar PASS

- Evaluar corpus real, representativo y anotado sin falsas/duplicadas
  recogidas ni finalizaciones prohibidas.
- Ejecutar toda la matriz adversarial y el recorrido físico completo en el
  dispositivo objetivo, con replay retenido y perfil sostenido.
- Implementar ARCore/Depth tras resolver la propiedad de cámara, o aprobar
  explícitamente el alcance reducido visual + IMU.
- Resolver licencias, assets, `applicationId` y firma productiva.
- Repetir la auditoría independiente sobre el commit y APK candidatos.
