import 'dart:async';

import '../../domain/cleanup/cleanup_event.dart';

class DomainEventBus {
  final StreamController<CleanupEvent> _controller =
      StreamController<CleanupEvent>.broadcast(sync: true);

  Stream<CleanupEvent> get events => _controller.stream;

  void publishAll(Iterable<CleanupEvent> events) {
    for (final event in events) {
      if (!_controller.isClosed) _controller.add(event);
    }
  }

  Future<void> dispose() => _controller.close();
}
