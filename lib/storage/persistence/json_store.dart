import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

/// A thin, defensive JSON layer over [SharedPreferences].
///
/// The persistence layer stores only small, safe metadata — lists of mission
/// records, a settings map, an active-mission marker. Each value is encoded as
/// a single JSON string under a namespaced key.
///
/// Every read is *defensive*: a missing key, malformed JSON, or a shape change
/// across app versions resolves to an empty/absent value rather than throwing.
/// A child's progress must never be lost to a crash on launch because one blob
/// went bad — the worst case is that one key resets to its default.
class JsonStore {
  const JsonStore(this._prefs);

  final SharedPreferences _prefs;

  /// Read a list of JSON objects stored under [key]. Returns an empty list if
  /// the key is absent or the stored value cannot be decoded into a list.
  List<Map<String, dynamic>> readObjectList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (e) {
      _warn('readObjectList', key, e);
      return const [];
    }
  }

  /// Persist a list of JSON objects under [key].
  Future<void> writeObjectList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      await _prefs.setString(key, jsonEncode(items));
    } catch (e) {
      _warn('writeObjectList', key, e);
    }
  }

  /// Read a single JSON object under [key], or `null` if absent/undecodable.
  Map<String, dynamic>? readObject(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, dynamic>();
    } catch (e) {
      _warn('readObject', key, e);
      return null;
    }
  }

  /// Persist a single JSON object under [key]. Passing `null` removes the key.
  Future<void> writeObject(String key, Map<String, dynamic>? value) async {
    try {
      if (value == null) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, jsonEncode(value));
      }
    } catch (e) {
      _warn('writeObject', key, e);
    }
  }

  /// Remove [key] entirely.
  Future<void> remove(String key) async {
    try {
      await _prefs.remove(key);
    } catch (e) {
      _warn('remove', key, e);
    }
  }

  void _warn(String op, String key, Object error) {
    if (kDebugMode) debugPrint('JsonStore.$op failed for "$key": $error');
  }
}
