# Veredicto de integración: 2.1.0

Veredicto de release: `PARTIAL`

Este documento distingue la integración técnica de la certificación comercial.
La evaluación se ejecutó en Windows el 2026-09-27 sobre la rama
`release/2.1.0`.

| Gate | Evidencia | Resultado |
|---|---|---|
| Arquitectura | `ToyCollected(` en producción sólo se crea en `cleanup_session_service.dart`; las demás capas lo consumen | `PASS` |
| Estático | 130 archivos sin cambios de formato; `flutter analyze`: 0 issues | `PASS` |
| Tests/replay | `flutter test -r expanded`: 88/88; incluye integración y regresiones de seguridad | `PASS` |
| Adversarial/percepción | corpus de ejemplo incompleto | `BLOCKED` para release |
| Gameplay | flujo Home → Scan cubierto por widgets; recorrido físico hasta Celebration pendiente | `PARTIAL` |
| Rendimiento/dispositivo | replay local: 40 frames, wall p95 84.00 ms, análisis p95 50.63 ms; recorrido físico final pendiente | `PARTIAL` |
| Privacidad | cámara e Internet loopback declarados; audio/storage removidos; evidencia local ignorada por Git | `PASS` |
| Comercial/firma | Ultralytics AGPL y firma productiva sin resolver | `BLOCKED` |
| Revisión independiente | no ejecutada | `BLOCKED` |

## Artefacto verificable

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Tamaño: `187920692` bytes.
- SHA-256: `C7FA51C0D83C17C21B680E4F1964DB493A41F111E15FA8107471F1CB6F9CCD8E`.
- Firma detectada: `C=US, O=Android, CN=Android Debug`.
- El validador del dataset de ejemplo devolvió `BLOCKED`, como se espera, por
  carecer de splits, sesiones reales, anotaciones y escenarios obligatorios.

## Condiciones para alcanzar PASS de release

- Evaluar un corpus real, representativo y anotado sin falsos eventos de
  recogida ni finalización prohibida.
- Completar el recorrido físico Home → Scan → Cleanup → Celebration y las
  pruebas adversariales en el dispositivo objetivo.
- Resolver licencia comercial del detector, sustituir el `applicationId` de
  ejemplo y configurar firma de producción.
- Obtener un veredicto independiente de un auditor que no haya implementado los
  cambios.
