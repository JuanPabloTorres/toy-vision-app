import 'package:flutter_test/flutter_test.dart';
import 'package:toyvision_realtime/business/cleanup_guidance_service.dart';
import 'package:toyvision_realtime/business/mission/cleanup_mission_status.dart';

void main() {
  const service = CleanupGuidanceService();

  String msg({
    required CleanupMissionStatus status,
    int known = 0,
    int collected = 0,
  }) =>
      service.message(
        missionStatus: status,
        knownCount: known,
        collectedCount: collected,
      );

  group('idle / scanning', () {
    test('idle invites a new mission', () {
      expect(
        msg(status: CleanupMissionStatus.idle),
        'Vamos a recoger juguetes.',
      );
    });

    test('scanning asks to move the camera slowly', () {
      expect(
        msg(status: CleanupMissionStatus.scanning),
        'Mueve la cámara despacito. Estoy buscando juguetes…',
      );
    });

    test('rescanning announces looking for another toy', () {
      expect(
        msg(status: CleanupMissionStatus.rescanning),
        'Voy a buscar otro juguete…',
      );
    });
  });

  group('active / targetLost (one toy at a time)', () {
    test('first toy: "Recoge el juguete marcado."', () {
      expect(
        msg(status: CleanupMissionStatus.active, collected: 0),
        'Recoge el juguete marcado.',
      );
    });

    test('after collecting one: nudges to the next', () {
      expect(
        msg(status: CleanupMissionStatus.active, collected: 1),
        '¡Muy bien! Ahora recoge este.',
      );
    });

    test('target lost says it is searching (box is hidden)', () {
      expect(
        msg(status: CleanupMissionStatus.targetLost, collected: 1),
        'No lo veo ahora. Muéveme un poquito para encontrarlo.',
      );
    });
  });

  group('asking / tapping', () {
    test('asking if more toys', () {
      expect(
        msg(status: CleanupMissionStatus.askingIfMoreToys),
        '¿Ves otro juguete?',
      );
    });

    test('no-toys fallback nudges another sweep (not a tap)', () {
      expect(
        msg(status: CleanupMissionStatus.waitingForChildTap),
        'No pude verlo bien. Acerca la cámara e intenta otra vez.',
      );
    });

    test('confirming pickup asks the rare manual fallback', () {
      expect(
        msg(status: CleanupMissionStatus.confirmingPickup),
        'No estoy seguro. ¿Lo recogiste?',
      );
    });
  });

  group('completed / error', () {
    test('completed singular', () {
      expect(
        msg(status: CleanupMissionStatus.completed, collected: 1),
        '¡Terminaste! Recogiste 1 juguete.',
      );
    });

    test('completed plural', () {
      expect(
        msg(status: CleanupMissionStatus.completed, collected: 4),
        '¡Terminaste! Recogiste 4 juguetes.',
      );
    });

    test('completed with zero', () {
      expect(
        msg(status: CleanupMissionStatus.completed, collected: 0),
        '¡Terminaste!',
      );
    });

    test('error', () {
      expect(
        msg(status: CleanupMissionStatus.error),
        'Algo salió mal. Toca «Reintentar».',
      );
    });
  });

  test('mascot name is Tobi', () {
    expect(service.mascotName(), 'Tobi');
  });
}
