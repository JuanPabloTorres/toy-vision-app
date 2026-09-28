sealed class CleanupEvent {
  const CleanupEvent(this.occurredAt);

  final DateTime occurredAt;
}

class CleanupStarted extends CleanupEvent {
  const CleanupStarted(super.occurredAt);
}

class ActiveToyChanged extends CleanupEvent {
  const ActiveToyChanged(super.occurredAt, this.trackId);

  final int trackId;
}

class ToyObserved extends CleanupEvent {
  const ToyObserved(super.occurredAt, this.trackId);
  final int trackId;
}

class ToyTrackCreated extends CleanupEvent {
  const ToyTrackCreated(super.occurredAt, this.trackId);
  final int trackId;
}

class ToyTemporarilyMissing extends CleanupEvent {
  const ToyTemporarilyMissing(super.occurredAt, this.trackId);
  final int trackId;
}

class ToyReappeared extends CleanupEvent {
  const ToyReappeared(super.occurredAt, this.trackId);
  final int trackId;
}

class NewToyDiscovered extends CleanupEvent {
  const NewToyDiscovered(super.occurredAt, this.trackId);
  final int trackId;
}

class ToyCollected extends CleanupEvent {
  const ToyCollected(super.occurredAt, this.trackId);
  final int trackId;
}

class CleanupProgressChanged extends CleanupEvent {
  const CleanupProgressChanged(
    super.occurredAt, {
    required this.collected,
    required this.remainingEstimate,
  });

  final int collected;
  final int remainingEstimate;
}

class RoomAlmostClean extends CleanupEvent {
  const RoomAlmostClean(super.occurredAt);
}

class EmptyRoomVerificationStarted extends CleanupEvent {
  const EmptyRoomVerificationStarted(super.occurredAt);
}

class RoomCleanConfirmed extends CleanupEvent {
  const RoomCleanConfirmed(super.occurredAt);
}

class CleanupCompleted extends CleanupEvent {
  const CleanupCompleted(super.occurredAt, this.collected);
  final int collected;
}

class PerceptionUncertain extends CleanupEvent {
  const PerceptionUncertain(super.occurredAt, this.reason);
  final String reason;
}
