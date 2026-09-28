# Toy Vision — visual assets

Drop the artwork here and the app picks it up automatically. Every widget
that consumes an asset degrades gracefully when the file is missing (it
shows a Material-icon fallback via `AppImage` / `LottieStatusView`), so
the app builds and runs with empty folders — but the experience is much
nicer once these are filled in.

## Folder layout

| Folder | What goes here |
|--------|----------------|
| `assets/background/` | Full-bleed scene backgrounds |
| `assets/icons/` | Original transparent Toy Vision UI icons |
| `assets/images/` | Illustrations and props |
| `assets/mascots/` | Tobi the robot in different poses |
| `assets/lottie/` | Animated `.json` (loading, scanning, celebration) |

## Expected files (referenced in code)

### background/
- `splash_playground.png` — Splash full background
- `home_playroom.png` — Home hero background
- `mission_room_bg.png` — (optional) behind the mission shell

### mascots/
- `robot_wave.png` — Splash + Home hero (Tobi waving)
- `robot_happy.png` — Home / progress
- `robot_guide.png` — Mission coach bubble avatar
- `robot_success.png` — Mission complete celebration

### images/
- `toy_basket.png` — Daily-mission card
- `child_avatar.png` — Home top-right avatar
- `daily_goal_illustration.png` — Daily goal card art
- `mission_card_illustration.png` — Generic mission art

### icons/
- The original kit contains 34 production icons across GAME, SYSTEM, PROGRESS
  and VISION. See `icons/GENERATED_ASSETS.md` for the complete inventory and
  reproducible subject prompts. They share one palette, material, camera angle
  and lighting model and are optimized to 512 px with transparent alpha.
- Material icons are retained only as runtime fallbacks and for secondary
  controls that do not define the Toy Vision brand.
- Every production asset must be registered in `ASSET_MANIFEST.yaml` before it
  can be referenced from Flutter.

### lottie/
- `mission_loading.json` — model loading
- `scanning_toys.json` — inspection phase
- `mission_complete.json` — celebration
- `happy_stars.json` / `success_star.json` — small success pop

## License note

Use assets licensed for redistribution (original output / CC0 / MIT /
purchased). Record source, author, license, commercial use, attribution and
original URL in `ASSET_MANIFEST.yaml` before adding a Flutter reference.
