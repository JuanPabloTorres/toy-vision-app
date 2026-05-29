/// Thrown for TFLite runtime problems: interpreter creation failure, unexpected
/// input/output tensor shapes, or preprocessing failure.
///
/// Callers treat this as a signal to fall back (at load time) or to drop the
/// current frame (at inference time) — never to crash the live loop.
class TfliteRuntimeException implements Exception {
  const TfliteRuntimeException(this.message);

  final String message;

  @override
  String toString() => 'TfliteRuntimeException: $message';
}
