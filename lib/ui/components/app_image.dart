import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/app_colors.dart';

/// Process-wide cache of "does this asset exist in the bundle?".
///
/// Without this, [AppImage] would call `rootBundle.load` on **every**
/// rebuild. On the Mission screen the camera drives ~10 rebuilds/second,
/// so the robot bubble and scan badge would hammer the bundle each frame.
/// The answer never changes during a run, so we cache it once per path.
final Map<String, Future<bool>> _assetExistsCache = {};

Future<bool> _assetExists(String path) {
  return _assetExistsCache.putIfAbsent(path, () async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Loads a PNG/JPG asset, falling back to a Material icon when the file
/// isn't present yet. Lets the whole UI reference planned `assets/...`
/// artwork before the real files land — placeholder icons until then.
///
/// The asset-existence check is cached (see [_assetExistsCache]) so this
/// is cheap to rebuild every frame.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.size,
    this.width,
    this.height,
    this.fallbackColor,
    this.fit = BoxFit.contain,
  });

  final String assetPath;
  final IconData fallbackIcon;

  /// Convenience square sizing. If set, overrides [width]/[height].
  final double? size;
  final double? width;
  final double? height;
  final Color? fallbackColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final w = size ?? width;
    final h = size ?? height;

    // Fast path: if we already know the asset exists, build the Image
    // directly with no FutureBuilder (no flicker, no async gap).
    final cached = _assetExistsCache[assetPath];
    return FutureBuilder<bool>(
      future: cached ?? _assetExists(assetPath),
      initialData: null,
      builder: (context, snap) {
        if (snap.data == true) {
          return Image.asset(assetPath, width: w, height: h, fit: fit);
        }
        if (snap.data == false) {
          return _fallback(w, h);
        }
        // Unknown yet (first probe in flight): reserve the space so the
        // layout doesn't jump, but draw nothing.
        return SizedBox(width: w, height: h);
      },
    );
  }

  Widget _fallback(double? w, double? h) => Icon(
        fallbackIcon,
        size: (w ?? h ?? 48) * 0.8,
        color: fallbackColor ?? AppColors.primaryBlue,
      );
}
