# Changelog

Todos los cambios relevantes de Toy Vision se documentan en este archivo. El
formato sigue Semantic Versioning.

## [2.4.5] - 2026-09-28

### Added

- Overlay de certificación disponible sólo en debug/profile con fase, conteos
  de propuestas y tracks, progreso, movimiento, reaparición, evidencia de
  retirada, cobertura, ventana limpia, decisión y bloqueadores.

### Changed

- El diagnóstico de cámara queda excluido de builds release y permanece
  separado del modo infantil.

### Fixed

- Una recogida rápida que ocurre entre frames puede confirmarse mediante el
  fondo estable revelado en la región original, sin exigir que el detector haya
  visto primero el objeto en movimiento.
- Una desaparición iniciada durante movimiento de cámara conserva esa causa y
  nunca usa la vía rápida de recogida, aunque el teléfono se estabilice luego.
- La cobertura final ya no cae visualmente a cero cuando la cámara está en
  movimiento; conserva los sectores ya revisados y continúa al estabilizarse.
- Las propuestas débiles/open-set dejan de bloquear indefinidamente la
  habitación limpia o de ampliar la misión como si fueran objetos confirmados.
- Un objeto nuevo sólo reabre la misión tras permanecer detector-confirmado en
  una vista estable, evitando volver a buscar por tracks transitorios del paneo.
- Desde su primer frame, todo objeto nuevo detector-confirmado pausa la ventana
  limpia para impedir una finalización prematura mientras se valida su admisión.
- El movimiento de una caja sólo cuenta como interacción física cuando la
  escena está estable; mover el teléfono ya no fabrica esa evidencia.
- Reactivar Modo infantil fuerza la superficie visual infantil y apaga el
  diagnóstico de cámara seleccionado previamente.

### Release notes

- Versión Flutter: `2.4.5+12`.

## [2.4.4] - 2026-09-28

### Fixed

- El clic tipo burbuja ahora es más largo, fuerte y distinguible en el altavoz
  de un teléfono.
- Al iniciar una misión, el clic recibe un breve espacio antes de que entren la
  música y la voz de Tobi, evitando que quede enmascarado.

### Release notes

- Versión Flutter: `2.4.4+11`.

## [2.4.3] - 2026-09-28

### Fixed

- La voz de Tobi deja de derivarse del locutor adulto CarlFM: las seis frases
  se regeneran con Parler-TTS Multilingual como un personaje infantil,
  brillante, alegre y juguetón en español.
- Las semillas quedan fijadas y cada frase se valida con reconocimiento de voz
  antes de empaquetarse para evitar palabras omitidas o inventadas.

### Release notes

- Versión Flutter: `2.4.3+10`.
- La síntesis se realiza offline durante desarrollo con un modelo Apache 2.0;
  la aplicación sólo incluye WAV locales y no descarga el modelo.

## [2.4.2] - 2026-09-28

### Fixed

- Las seis frases de Tobi reciben un tratamiento sintético juvenil de tono y
  formantes para evitar el timbre de narrador adulto y sonar más infantil,
  ligero y juguetón sin depender de servicios externos.

### Release notes

- Versión Flutter: `2.4.2+9`.
- La voz se genera y procesa offline; no se graba ni distribuye la voz real de
  ningún niño.

## [2.4.1] - 2026-09-28

### Fixed

- La música y la primera frase de Tobi comienzan al entrar a la misión, sin
  depender de que termine el escaneo inicial del cuarto.
- La mezcla de música y voz usa niveles audibles y conserva una reducción
  moderada de la música mientras Tobi habla.
- Los botones para iniciar la misión y comenzar el escaneo reproducen un
  sonido corto tipo burbuja respetando los ajustes de sonido del usuario.

### Release notes

- Versión Flutter: `2.4.1+8`.

## [2.4.0] - 2026-09-27

### Added

- Vocabulario on-device ampliado de 20 a 30 clases para conservar todos los
  juguetes y proponer también ropa y objetos domésticos sueltos.
- Regresión multiobjeto para tres elementos pequeños simultáneos con jitter
  normal de cajas del detector.

### Changed

- El umbral nativo de propuestas baja de 0.25 a 0.12; la confirmación sigue
  requiriendo persistencia, estabilidad espacial y fusión independiente.
- La estabilidad temporal adapta la tolerancia de desplazamiento al tamaño de
  la caja para evitar perder objetos pequeños por variación de pocos píxeles.

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
