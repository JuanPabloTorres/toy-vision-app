import 'package:flutter/material.dart';

import '../../app/app_router.dart';
import '../../ui/app_assets.dart';
import '../../ui/components/app_image.dart';
import '../../ui/components/toy_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_radii.dart';
import '../../ui/theme/app_shadows.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

enum ToyAppSection { home, progress, settings, about }

/// Shared responsive structure for every primary Toy Vision screen.
///
/// The shell owns only presentation concerns: safe areas, bounded content,
/// scrolling and primary navigation. It deliberately has no access to cleanup
/// state or perception events.
class ToyAppShell extends StatelessWidget {
  const ToyAppShell({
    super.key,
    required this.section,
    required this.child,
    this.title,
    this.header,
    this.backgroundAsset = AppAssets.homeBackground,
    this.backgroundOverlay = const Color(0xEAF5FBFF),
    this.maxContentWidth = 720,
    this.showNavigation = true,
    this.onBack,
  }) : assert(title != null || header != null);

  final ToyAppSection section;
  final Widget child;
  final String? title;
  final Widget? header;
  final String backgroundAsset;
  final Color backgroundOverlay;
  final double maxContentWidth;
  final bool showNavigation;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: showNavigation
          ? ToyBottomNavigation(
              selected: section,
              onSelected: (destination) =>
                  _selectDestination(context, destination),
            )
          : null,
      body: ToyBackground(
        asset: backgroundAsset,
        overlay: backgroundOverlay,
        safeArea: false,
        child: SafeArea(
          bottom: !showNavigation,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 360
                  ? AppSpacing.md
                  : constraints.maxWidth < 700
                      ? AppSpacing.lg
                      : AppSpacing.xl;
              final pageHeader = header ??
                  ToyScreenHeader(
                    title: title!,
                    onBack: onBack,
                  );
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      AppSpacing.md,
                      horizontalPadding,
                      AppSpacing.sm,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: pageHeader,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('toy-shell-scroll'),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        AppSpacing.sm,
                        horizontalPadding,
                        AppSpacing.xl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: maxContentWidth,
                            minHeight: constraints.maxHeight > 112
                                ? constraints.maxHeight - 112
                                : 0,
                          ),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectDestination(
    BuildContext context,
    ToyAppSection destination,
  ) {
    if (destination == section) return;
    final route = switch (destination) {
      ToyAppSection.home => AppRoutes.home,
      ToyAppSection.progress => AppRoutes.progress,
      ToyAppSection.settings => AppRoutes.settings,
      ToyAppSection.about => AppRoutes.about,
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }
}

class ToyBottomNavigation extends StatelessWidget {
  const ToyBottomNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ToyAppSection selected;
  final ValueChanged<ToyAppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: AppColors.shadowMedium,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            _NavigationItem(
              key: const Key('nav-home'),
              section: ToyAppSection.home,
              selected: selected == ToyAppSection.home,
              label: 'Inicio',
              assetPath: AppAssets.homeIcon,
              fallbackIcon: Icons.home_rounded,
              onSelected: onSelected,
            ),
            _NavigationItem(
              key: const Key('progress-action'),
              section: ToyAppSection.progress,
              selected: selected == ToyAppSection.progress,
              label: 'Progreso',
              assetPath: AppAssets.progressIcon,
              fallbackIcon: Icons.auto_graph_rounded,
              onSelected: onSelected,
            ),
            _NavigationItem(
              key: const Key('adult-settings'),
              section: ToyAppSection.settings,
              selected: selected == ToyAppSection.settings,
              label: 'Ajustes',
              assetPath: AppAssets.settingsIcon,
              fallbackIcon: Icons.settings_rounded,
              onSelected: onSelected,
            ),
            _NavigationItem(
              key: const Key('about-action'),
              section: ToyAppSection.about,
              selected: selected == ToyAppSection.about,
              label: 'Acerca',
              assetPath: AppAssets.infoIcon,
              fallbackIcon: Icons.info_rounded,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    super.key,
    required this.section,
    required this.selected,
    required this.label,
    required this.assetPath,
    required this.fallbackIcon,
    required this.onSelected,
  });

  final ToyAppSection section;
  final bool selected;
  final String label;
  final String assetPath;
  final IconData fallbackIcon;
  final ValueChanged<ToyAppSection> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => onSelected(section),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 64),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.surfaceSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: selected
                  ? Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.22),
                    )
                  : null,
              boxShadow: selected ? AppShadows.card : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppImage(
                  assetPath: assetPath,
                  fallbackIcon: fallbackIcon,
                  fallbackColor: AppColors.primaryBlue,
                  size: selected ? 34 : 31,
                ),
                const SizedBox(height: AppSpacing.xxs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTypography.caption.copyWith(
                      color: selected
                          ? AppColors.primaryBlue
                          : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
