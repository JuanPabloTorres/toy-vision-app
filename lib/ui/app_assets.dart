/// Single source of truth for asset paths. The real artwork currently
/// lives under `assets/images/` with these exact filenames — keeping the
/// paths here means a future reorg (e.g. moving the robot to
/// `assets/mascots/`) is a one-line change instead of a hunt across
/// widgets.
class AppAssets {
  AppAssets._();

  static const String _img = 'assets/images';

  // Backgrounds
  static const String homeBackground = '$_img/home_background.png';
  static const String splashBackground = '$_img/home_background.png';
  static const String missionBackground = '$_img/mision_background.png';

  // Mascot
  static const String robotMascot = '$_img/icon_robot_mascot.png';

  // App branding
  static const String appIcon = '$_img/toy_vision_app_icon.png';
}
