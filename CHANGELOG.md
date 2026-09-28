# Changelog

Todos los cambios relevantes de Toy Vision se documentan en este archivo. El
formato sigue Semantic Versioning.

## [2.3.0] - 2026-09-27

### Added

- Voz alegre en español para Tobi durante inicio, recogida, revisión,
  incertidumbre y celebración.
- Música chiptune original y reproducible para la misión, sin melodías ni
  muestras de terceros.

### Changed

- Música, efectos y voz se mezclan en canales independientes; la música baja
  mientras Tobi habla y cada interruptor de ajustes silencia su canal real.

### Release notes

- Versión Flutter: `2.3.0+6`.
- Los nuevos audios funcionan completamente offline. La validación auditiva en
  dispositivo físico sigue pendiente antes de certificar una release.

## [2.2.0] - 2026-09-27

### Added

- Fusión de movimiento físico con giroscopio, aceleración lineal y rotation
  vector nativos de Android, sin permisos sensibles adicionales.
- `SensorFusionEngine` para combinar movimiento, continuidad visual,
  background reveal y hooks opcionales de pose/profundidad.
- `RoomCoverageTracker` con sectores izquierda, centro, derecha y piso, más
  fallback por viewpoints visuales cuando la orientación no está disponible.
- Instrumentación de desarrollador para juguete activo, ausencia, movimiento,
  background reveal, depth, cobertura y decisión de limpieza.

### Changed

- La verificación final devuelve `toyFound`, `needMoreCoverage` o `roomClean` y
  siempre explica al niño qué zona mirar o qué evidencia falta.
- La ruta infantil sustituye el paso bloqueante “Revisar” por “Confirmar” y
  conserva YOLO/percepción activos durante toda la comprobación.

### Safety

- El movimiento brusco del dispositivo mantiene el juguete como
  `temporarilyLost`; nunca confirma una recogida.
- ARCore/Depth no se simulan sobre CameraX: quedan detrás de contratos
  opcionales hasta migrar el dueño de cámara a ARCore Shared Camera/Camera2.

## [2.1.0] - 2026-09-27

### Added

- Nueva arquitectura por dominio, aplicación, percepción, infraestructura y
  presentación, con contratos explícitos para el ciclo de limpieza.
- Home, ruta de misión, visión y celebración con un lenguaje visual infantil
  uniforme, assets propios y feedback de progreso.
- Harness de replay/certificación, escenarios adversariales y pruebas de
  integración y rendimiento.

### Changed

- Flujo principal optimizado para detectar, recoger físicamente, verificar la
  desaparición, continuar con el siguiente juguete, comprobar el área y celebrar.
- Seguimiento, reidentificación, estabilidad de escena y ajuste de cajas para
  reducir duplicados y alinear el overlay con el objeto real.
- Verificación del juguete activo con mayor cadencia y progreso visible.

### Fixed

- La recogida ya no depende de la mera pérdida de tracking ni de una escena
  vacía; requiere evidencia temporal confirmada sobre el snapshot inicial.
- Corrección de la orientación entre las cajas del detector y los píxeles usados
  por el análisis para evitar cajas desplazadas o sobredimensionadas.
- Continuación y finalización de la sesión después de una recogida confirmada.
- Carrera de inicialización al comenzar desde Home, evitando que la captura de
  evidencia interrumpa la navegación hacia la misión.

### Release notes

- Versión Flutter: `2.1.0+4`.
- La validación comercial continúa condicionada por corpus físico completo,
  revisión independiente, licencia del detector y firma de producción.
