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
| `assets/icons/` | Small single-purpose PNG icons |
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
- `icon_star.png`, `icon_calendar.png`, `icon_camera.png`,
  `icon_rocket.png`, `icon_trophy.png`, `icon_play.png`,
  `icon_pause.png`, `icon_stop.png`, `icon_home.png`,
  `icon_history.png`, `icon_parents.png`
- Note: the bottom-nav and buttons currently use **Material icons**
  (rounded variants) so they look consistent before the PNG icon set
  lands. Swap to PNGs by passing an `assetPath` to `AppImage`.

### lottie/
- `mission_loading.json` — model loading
- `scanning_toys.json` — inspection phase
- `mission_complete.json` — celebration
- `happy_stars.json` / `success_star.json` — small success pop

## License note

Use assets licensed for redistribution (CC0 / MIT / purchased). Keep
attribution here when adding files.
