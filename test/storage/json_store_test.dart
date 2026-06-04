import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toyvision_realtime/storage/persistence/json_store.dart';

Future<JsonStore> _store([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  return JsonStore(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JsonStore object list', () {
    test('absent key reads as empty list', () async {
      final store = await _store();
      expect(store.readObjectList('missing'), isEmpty);
    });

    test('round-trips a list of objects', () async {
      final store = await _store();
      await store.writeObjectList('k', [
        {'a': 1},
        {'a': 2},
      ]);
      final back = store.readObjectList('k');
      expect(back, hasLength(2));
      expect(back.first['a'], 1);
      expect(back.last['a'], 2);
    });

    test('malformed JSON reads as empty (never throws)', () async {
      final store = await _store({'k': 'not json at all {{{'});
      expect(store.readObjectList('k'), isEmpty);
    });

    test('a JSON object (not a list) under a list key reads as empty', () async {
      final store = await _store({'k': '{"a":1}'});
      expect(store.readObjectList('k'), isEmpty);
    });
  });

  group('JsonStore single object', () {
    test('absent key reads as null', () async {
      final store = await _store();
      expect(store.readObject('missing'), isNull);
    });

    test('round-trips a single object', () async {
      final store = await _store();
      await store.writeObject('k', {'x': true, 'n': 7});
      final back = store.readObject('k');
      expect(back, isNotNull);
      expect(back!['x'], isTrue);
      expect(back['n'], 7);
    });

    test('writing null removes the key', () async {
      final store = await _store({'k': '{"x":1}'});
      await store.writeObject('k', null);
      expect(store.readObject('k'), isNull);
    });

    test('malformed JSON reads as null (never throws)', () async {
      final store = await _store({'k': 'garbage'});
      expect(store.readObject('k'), isNull);
    });
  });
}
