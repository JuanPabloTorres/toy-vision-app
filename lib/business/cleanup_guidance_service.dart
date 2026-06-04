import 'mission/cleanup_mission_status.dart';

/// Pre-baked, kid-language coach copy for "Misión Recoge Juguetes".
///
/// Phase 7: one short message at a time, never technical (no "detección",
/// "modelo", "snapshot", "bounding box"). The controller may override with
/// a transient line (e.g. "Apunta la cámara al juguete") via its own
/// pending-message mechanism; this service provides the steady-state copy.
class CleanupGuidanceService {
  const CleanupGuidanceService();

  String message({
    required CleanupMissionStatus missionStatus,
    required int knownCount,
    required int collectedCount,
  }) {
    switch (missionStatus) {
      case CleanupMissionStatus.error:
        return 'Algo salió mal. Toca «Reintentar».';

      case CleanupMissionStatus.idle:
        return 'Vamos a recoger juguetes.';

      case CleanupMissionStatus.scanning:
        return 'Mueve la cámara despacito. Estoy buscando juguetes…';

      case CleanupMissionStatus.active:
      case CleanupMissionStatus.targetLost:
        if (missionStatus == CleanupMissionStatus.targetLost) {
          // The box is hidden while the toy isn't seen — say so plainly so the
          // child moves the camera instead of trusting a frozen marker.
          return 'No lo veo ahora. Muéveme un poquito para encontrarlo.';
        }
        if (collectedCount == 0) {
          return 'Recoge el juguete marcado.';
        }
        return '¡Muy bien! Ahora recoge este.';

      case CleanupMissionStatus.confirmingPickup:
        return 'No estoy seguro. ¿Lo recogiste?';

      case CleanupMissionStatus.rescanning:
        return 'Voy a buscar otro juguete…';

      case CleanupMissionStatus.cleanAreaVerification:
        return 'Estoy revisando el área…';

      case CleanupMissionStatus.askingIfMoreToys:
        return '¿Ves otro juguete?';

      case CleanupMissionStatus.waitingForChildTap:
        // Automatic-first: the fallback nudges another camera sweep, not a
        // tap. (Tapping still works silently; "Necesito ayuda" shows the
        // explicit tap hint.)
        return 'No pude verlo bien. Acerca la cámara e intenta otra vez.';

      case CleanupMissionStatus.completed:
        if (collectedCount > 0) {
          final juguete = collectedCount == 1 ? 'juguete' : 'juguetes';
          return '¡Terminaste! Recogiste $collectedCount $juguete.';
        }
        return '¡Terminaste!';

      case CleanupMissionStatus.cancelled:
        return '';
    }
  }

  /// Mascot prefix shown above the message in the bubble.
  String mascotName() => 'Tobi';
}
