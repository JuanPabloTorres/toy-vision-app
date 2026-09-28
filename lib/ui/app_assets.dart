/// Single source of truth for asset paths. The real artwork currently
/// lives under `assets/images/` with these exact filenames — keeping the
/// paths here means a future reorg (e.g. moving the robot to
/// `assets/mascots/`) is a one-line change instead of a hunt across
/// widgets.
class AppAssets {
  AppAssets._();

  static const String _img = 'assets/images';
  static const String _icons = 'assets/icons';

  // Backgrounds
  static const String homeBackground = '$_img/home_background.png';
  static const String missionBackground = '$_img/mision_background.png';

  // Mascot
  static const String robotMascot = '$_img/icon_robot_mascot.png';

  // Original Toy Vision 3D icon kit. These are presentation assets only;
  // Material symbols remain as accessible fallbacks in each consumer.

  // GAME
  static const String carIcon = '$_icons/toy_car_3d.png';
  static const String bearIcon = '$_icons/toy_bear_3d.png';
  static const String ballIcon = '$_icons/toy_ball_3d.png';
  static const String blocksIcon = '$_icons/toy_blocks_3d.png';
  static const String dinosaurIcon = '$_icons/toy_dinosaur_3d.png';
  static const String trainIcon = '$_icons/toy_train_3d.png';
  static const String puzzleIcon = '$_icons/toy_puzzle_3d.png';

  // SYSTEM
  static const String cameraIcon = '$_icons/toy_camera_3d.png';
  static const String soundIcon = '$_icons/toy_sound_3d.png';
  static const String musicIcon = '$_icons/toy_music_3d.png';
  static const String settingsIcon = '$_icons/toy_settings_3d.png';
  static const String homeIcon = '$_icons/toy_home_3d.png';
  static const String replayIcon = '$_icons/toy_replay_3d.png';
  static const String backIcon = '$_icons/toy_back_3d.png';
  static const String infoIcon = '$_icons/toy_info_3d.png';
  static const String voiceIcon = '$_icons/toy_voice_3d.png';
  static const String animationIcon = '$_icons/toy_animation_3d.png';
  static const String childModeIcon = '$_icons/toy_child_mode_3d.png';
  static const String privacyIcon = '$_icons/toy_privacy_3d.png';
  static const String modelIcon = '$_icons/toy_model_3d.png';
  static const String licenseIcon = '$_icons/toy_license_3d.png';
  static const String supportIcon = '$_icons/toy_support_3d.png';

  // PROGRESS
  static const String progressIcon = '$_icons/toy_progress_3d.png';
  static const String trophyIcon = '$_icons/toy_trophy_3d.png';
  static const String starIcon = '$_icons/toy_star_3d.png';
  static const String streakIcon = '$_icons/toy_streak_3d.png';
  static const String completedIcon = '$_icons/toy_completed_3d.png';
  static const String rewardIcon = '$_icons/toy_reward_3d.png';

  // VISION
  static const String scanIcon = '$_icons/toy_scan_3d.png';
  static const String searchIcon = '$_icons/toy_search_3d.png';
  static const String confirmedIcon = '$_icons/toy_confirmed_3d.png';
  static const String targetIcon = '$_icons/toy_target_3d.png';
  static const String collectedIcon = '$_icons/toy_collected_3d.png';
  static const String emptyRoomIcon = '$_icons/toy_empty_room_3d.png';
}
