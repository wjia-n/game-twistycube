# Twisty Cube — Rules

The authoritative source of truth for Twisty Cube gameplay. The engine
(`lib/engine/cube_engine.dart`) enforces these rules; if the implementation
ever diverges, fix the implementation.

## 1. Objective

Unscramble the cube: turn faces until all six faces show a single solid
color each (white on Up, red on Right, green on Front, yellow on Down,
blue on Back, orange on Left in the Classic Toy theme; the exact hues
follow the active theme).

## 2. Setup

- The player picks a cube: Pocket 2×2, Classic 3×3, or Master 4×4
  (3×3 and 4×4 are Pro).
- The player picks Relaxed (no clock) or Timed (countdown per tier) mode
  (Timed is Pro).
- The engine applies a random scramble: 12 moves (2×2), 25 moves (3×3),
  or 40 moves (4×4). Scramble moves are animated one by one, visibly.
- The move counter and clock reset to zero when the scramble finishes.

## 3. Turn order

Single-player puzzle: the player always acts. There are no opponents,
no passes, no skipped turns.

## 4. Legal moves

- Select any of the six faces (U, R, F, D, B, L) by tapping one of its
  stickers or its face chip.
- Turn the selected face 90° clockwise or 90° counter-clockwise using the
  twist buttons. Both directions are always legal.
- Moves are only accepted while the engine is in the `ready` phase
  (not mid-animation, not mid-scramble, not while solved or paused).

## 5. Illegal moves

- Turning a face while an animation or the scramble is running is
  rejected with an "invalid" sound; the cube state does not change.
- Turning a face after the cube is solved does nothing until a new
  scramble starts.
- There is no "undo" of a twist: every quarter-turn counts as one move.

## 6. Captures

Not applicable — no pieces are captured in a twisty cube.

## 7. Special rules

- Scramble generation never immediately undoes its previous move, and a
  scramble that accidentally leaves the cube solved is extended.
- Face turns are quarter-turns only (90°). Half-turns (180°) are not
  offered; two quarter-turns achieve the same result.
- The cube view can be orbited freely by dragging; orbiting never
  changes cube state.

## 8. Scoring

- Each accepted face turn adds exactly 1 to the move counter.
- The clock runs from the end of the scramble until the solve (Relaxed)
  or counts down from the tier limit (Timed).
- Star rating on solve (1–3):
  - 3 stars: time within par AND moves within par.
  - 2 stars: time within 2× par.
  - 1 star: solved, slower than that. Solving always earns at least 1 star.
- Pars: 2×2 — 90 s / 30 moves; 3×3 — 360 s / 140 moves;
  4×4 — 720 s / 300 moves.

## 9. Winning conditions

The cube is solved — and the win fanfare + results dialog trigger —
if and only if every sticker on each face matches that face's color,
checked immediately after each turn animation settles.

## 10. Draw conditions

Not applicable — single-player puzzle, always decisive.

## 11. AI strategy

Not applicable — no AI opponent. The scramble uses a uniform random
face/direction choice with an anti-undo filter.

## 12. Edge cases

- App backgrounded mid-game: the engine pauses and its clock stops;
  resuming restores the exact pre-pause phase.
- App backgrounded mid-turn-animation: the watchdog settles the turn
  within 4 seconds; the state can never stick half-turned.
- Timed mode reaching zero: the game ends as a loss ("Time's up"),
  the cube freezes, and the player may retry or quit.
- Audio interrupted (call): music pauses and resumes exactly where it
  left off; it never silently dies or restarts.

## 13. Test cases

Automated in `test/cube_engine_test.dart` (mirrors pre-validated
Python checks):

1. Every face turn has order 4 (four identical turns = identity),
   for 2×2, 3×3 and 4×4.
2. A 40-move deterministic scramble followed by its exact inverse
   sequence returns the cube to solved, for all sizes.
3. The classic sexy move (R U R' U') has order 6, for all sizes —
   the signature property of a correct cube group.
4. Solved detection: the pristine cube reads solved; flipping one
   sticker reads unsolved.
5. Sticker 3D coordinates are unique per cube (no two stickers share
   a position).

Manual checks:

6. Scramble animation plays visibly; the cube is never handed over
   already solved.
7. Turning during animation/scramble is rejected (invalid sound),
   state unchanged.
8. Pause → background → resume keeps clock and phase.
9. Win dialog appears exactly once per solve with correct stars/stats.
10. Timed mode at zero shows "Time's up" once.
