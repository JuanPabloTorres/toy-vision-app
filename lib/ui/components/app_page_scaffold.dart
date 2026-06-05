import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_image.dart';
import 'app_screen_header.dart';

/// The shared page skeleton for every screen.
///
/// Before this, each screen reinvented its root: some used `Scaffold`, some a
/// raw `Stack`, some a bare `SafeArea`; page margins and safe-area handling
/// drifted screen to screen. This wraps that structure once:
///
/// * an optional full-bleed [backgroundAsset] behind everything,
/// * a `SafeArea` (top always; bottom opt-in via [safeAreaBottom]),
/// * the standard page [padding] (16 sides, comfortable top/bottom),
/// * a fixed [header] (use [AppScreenHeader]) that never scrolls away,
/// * the [body], which scrolls when [scrollable] is true,
/// * an optional [bottomAction] pinned below the body (e.g. a primary CTA).
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    this.header,
    required this.body,
    this.bottomAction,
    this.backgroundAsset,
    this.scrollable = true,
    this.padding = defaultPadding,
    this.safeAreaBottom = false,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  /// Fixed header shown above the body. Typically an [AppScreenHeader].
  final AppScreenHeader? header;

  /// The page content below the header.
  final Widget body;

  /// Optional control pinned at the bottom, outside the scroll area.
  final Widget? bottomAction;

  /// Optional full-bleed background image asset path.
  final String? backgroundAsset;

  /// When true (default) the body scrolls; when false it fills the space.
  final bool scrollable;

  /// Page margin around the content. Defaults to [defaultPadding].
  final EdgeInsets padding;

  /// Whether to inset the bottom for the system safe area. Off by default so
  /// content can sit above the app's bottom navigation bar.
  final bool safeAreaBottom;

  final CrossAxisAlignment crossAxisAlignment;

  /// The standard page margin: 16 on the sides, a calm 12/16 top/bottom.
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.md,
    AppSpacing.lg,
    AppSpacing.lg,
  );

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (header != null) ...[
          header!,
          const SizedBox(height: AppSpacing.md),
        ],
        Expanded(
          child: scrollable
              ? SingleChildScrollView(child: body)
              : body,
        ),
        if (bottomAction != null) ...[
          const SizedBox(height: AppSpacing.md),
          bottomAction!,
        ],
      ],
    );

    final padded = SafeArea(
      bottom: safeAreaBottom,
      child: Padding(padding: padding, child: content),
    );

    if (backgroundAsset == null) return padded;

    return Stack(
      children: [
        Positioned.fill(
          child: AppImage(
            assetPath: backgroundAsset!,
            fallbackIcon: Icons.blur_on,
            fallbackColor: Colors.transparent,
            fit: BoxFit.cover,
          ),
        ),
        padded,
      ],
    );
  }
}
