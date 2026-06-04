/// Local, offline app preferences for the Parents section and playful audio.
///
/// Counts/flags only — no personal data is ever stored. `soundEnabled` is
/// mirrored from the audio service's existing preference key (the single
/// source of truth for sound), so this model gives a unified settings *view*
/// without a second store fighting it. `musicEnabled`, `hapticsEnabled`, and
/// `parentModeEnabled` are owned and persisted by the settings store itself.
///
/// Note: the spec's `lastSelectedDetectorMode` is intentionally omitted — the
/// mock/tflite detector split was archived in Phase 5; there is a single YOLO
/// detector now, so the field has no meaning.
class AppSettings {
  const AppSettings({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.parentModeEnabled = false,
  });

  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final bool parentModeEnabled;

  /// First-run defaults (sound/music/haptics on, parent mode off).
  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    bool? parentModeEnabled,
  }) =>
      AppSettings(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        musicEnabled: musicEnabled ?? this.musicEnabled,
        hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
        parentModeEnabled: parentModeEnabled ?? this.parentModeEnabled,
      );

  /// Only the store-owned settings are serialized. `soundEnabled` is read from
  /// the audio service's key, so it is deliberately NOT part of this JSON.
  Map<String, dynamic> toJson() => {
        'musicEnabled': musicEnabled,
        'hapticsEnabled': hapticsEnabled,
        'parentModeEnabled': parentModeEnabled,
      };

  factory AppSettings.fromJson(
    Map<String, dynamic> j, {
    required bool soundEnabled,
  }) =>
      AppSettings(
        soundEnabled: soundEnabled,
        musicEnabled: j['musicEnabled'] as bool? ?? true,
        hapticsEnabled: j['hapticsEnabled'] as bool? ?? true,
        parentModeEnabled: j['parentModeEnabled'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.soundEnabled == soundEnabled &&
      other.musicEnabled == musicEnabled &&
      other.hapticsEnabled == hapticsEnabled &&
      other.parentModeEnabled == parentModeEnabled;

  @override
  int get hashCode => Object.hash(
        soundEnabled,
        musicEnabled,
        hapticsEnabled,
        parentModeEnabled,
      );
}
