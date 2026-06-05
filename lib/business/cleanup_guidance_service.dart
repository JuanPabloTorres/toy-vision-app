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
    int? targetPickupGoal,
    int? pickupsToGoal,
    bool hasReachedGoal = false,
    bool isNewRecord = false,
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
          return 'Lo perdí un momento. Apunta aquí otra vez.';
        }
        // The counter is a CHALLENGE score: celebrate progress toward the goal
        // and, once reached, invite breaking the record. "Te faltan N" means N
        // until the goal — never "N toys left in the room".
        if (collectedCount == 0) {
          return 'Vamos por este primero.';
        }
        if (isNewRecord) {
          return '¡Nuevo récord! Sigue por más.';
        }
        if (hasReachedGoal) {
          return '¡Reto completado! Sigue para tu récord.';
        }
        if (pickupsToGoal != null && pickupsToGoal > 0) {
          final falta = pickupsToGoal == 1
              ? 'Te falta 1 para el reto.'
              : 'Te faltan $pickupsToGoal para el reto.';
          return '¡Muy bien! $falta';
        }
        return '¡Muy bien! Vamos por este.';

      case CleanupMissionStatus.confirmingPickup:
        return 'No estoy seguro. Apunta otra vez al área.';

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
          if (isNewRecord) {
            return '¡Nuevo récord! Recogiste $collectedCount $juguete.';
          }
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
