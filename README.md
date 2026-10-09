# Twisty Cube

A juicy little twisty-cube puzzle by Wajiha. Pick your cube — Pocket 2×2,
Classic 3×3, or Master 4×4 — get a fully animated scramble, then twist
faces until all six sides are solid again. Relaxed or timed, with best
times, star ratings, 12 toy-like themes, 8 sticker styles, and a custom
theme creator.

Package: `com.gameswajiha.twistycube`

## Structure

- `lib/engine/cube_engine.dart` — generalized NxN cube logic, engine-owned
  state machine (idle → scrambling → ready → turning → solved) + watchdog.
  Face-turn permutations are derived from 3D rotation and validated in
  `test/cube_engine_test.dart` (order-4 turns, inverse re-solve, sexy-move
  order-6 for 2×2/3×3/4×4).
- `lib/widgets/cube_view.dart` — interactive pseudo-3D cube: drag to orbit,
  tap a sticker to select a face, physically animated face turns, shaded
  tiles in the active theme + sticker style.
- `lib/services/audio_service.dart` — synthesized, cached audio with
  busy-guard and lifecycle pause/resume. Menu music, game BGM, and all SFX.
- `lib/services/settings_service.dart` — persisted settings; player name
  stored as one order-preserving JSON string (`twistycube_player_names_json`).
- `lib/services/iap_service.dart` — real Play Billing: `twistycubepro`
  (one-time), `twistycubecoffee` / `twistycubechocolate` (tips).
- `lib/theme/cube_themes.dart` — 12 physical-material themes + 8 sticker
  styles + custom theme builder.
- `lib/screens/` — splash (WAJIHA moment → game splash), menu, game,
  settings + theme picker, custom theme creator, Pro (Free-vs-Pro).
- `RULES.md` — the 13-section rules document; the engine enforces it.

## Build

Standard Flutter app. CI builds the APK + AAB. See the game-factory
docs for the shared release flow.
