import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twistycube/engine/cube_engine.dart';
import 'package:twistycube/screens/game_screen.dart';
import 'package:twistycube/screens/menu_screen.dart';
import 'package:twistycube/services/audio_service.dart';
import 'package:twistycube/services/settings_service.dart';
import 'package:twistycube/widgets/cube_view.dart';

/// Regression tests for Twisty Cube stats: solves increment on completion,
/// per-tier bests update only when beaten, stats persist across restarts,
/// and stats display on the menu strip and the win dialog.
void main() {
  test('recordSolve increments solves and updates bests only when beaten',
      () async {
    SharedPreferences.setMockInitialValues({});
    final s = CubeSettings();
    await s.load();

    await s.recordSolve(tierIndex: 1, timeMs: 90000, moves: 60);
    expect(s.solves, 1);
    expect(s.bestTimeMs[1], 90000);
    expect(s.bestMoves[1], 60);

    // Slower solve: solves still increments, bests do not regress.
    await s.recordSolve(tierIndex: 1, timeMs: 120000, moves: 80);
    expect(s.solves, 2);
    expect(s.bestTimeMs[1], 90000);
    expect(s.bestMoves[1], 60);

    // Faster solve: bests improve.
    await s.recordSolve(tierIndex: 1, timeMs: 45000, moves: 40);
    expect(s.solves, 3);
    expect(s.bestTimeMs[1], 45000);
    expect(s.bestMoves[1], 40);

    // Other tiers untouched.
    expect(s.bestTimeMs[0], 0);
    expect(s.bestTimeMs[2], 0);

    // Persistence: a fresh instance reads the same values.
    final s2 = CubeSettings();
    await s2.load();
    expect(s2.solves, 3);
    expect(s2.bestTimeMs[1], 45000);
    expect(s2.bestMoves[1], 40);
  });

  testWidgets('menu stats strip shows persisted solves and best',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'twistycube_solves': 7,
      'twistycube_best_time_ms_0': 95400,
      'twistycube_best_moves_0': 42,
    });
    final settings = CubeSettings();
    await settings.load();
    final audio = CubeAudio();
    await tester.pumpWidget(
      MaterialApp(home: MenuScreen(audio: audio, settings: settings)),
    );
    await tester.pump();
    expect(find.text('7'), findsOneWidget); // solves count
    expect(find.text('Best'), findsOneWidget); // best label
    expect(find.text('01:35'), findsOneWidget); // 95400ms formatted
    audio.dispose();
  });

  testWidgets('full win path via real UI records stats and shows dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = CubeSettings();
    await settings.load();
    final audio = CubeAudio();
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(audio: audio, settings: settings)),
    );
    await tester.pump();

    CubeEngine engineOf() =>
        tester.widget<CubeView>(find.byType(CubeView)).engine;

    // Advance fake async through the animated scramble (2x2: 12 x 130ms).
    for (int i = 0; i < 40 && engineOf().phase != CubePhase.ready; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(engineOf().phase, CubePhase.ready);

    // Rig a near-solved cube, then play two REAL turns through the UI's
    // animation handshake: turn -> animation completes -> finishTurn.
    final engine = engineOf();
    final n = engine.size;
    engine.stickers = [for (int i = 0; i < 6 * n * n; i++) i ~/ (n * n)];
    Future<void> settleTurn() async {
      for (int i = 0; i < 20 && engine.phase == CubePhase.turning; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    expect(engine.turn(2, true), isTrue); // unsolve
    await settleTurn();
    expect(engine.phase, CubePhase.ready);
    expect(engine.turn(2, false), isTrue); // the winning turn
    await settleTurn();
    expect(engine.phase, CubePhase.solved);

    // _onWin records stats asynchronously; flush.
    for (int i = 0; i < 50 && settings.solves == 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(settings.solves, 1);
    expect(settings.bestTimeMs[0], greaterThan(0));
    expect(settings.bestMoves[0], greaterThan(0));

    // Win dialog is up and shows the fresh best.
    expect(find.text('Solved!'), findsWidgets);
    expect(find.textContaining('Best:'), findsOneWidget);

    // Stats survive an app restart.
    final s2 = CubeSettings();
    await s2.load();
    expect(s2.solves, 1);
    expect(s2.bestTimeMs[0], settings.bestTimeMs[0]);

    audio.dispose();
    // NOTE: the engine is owned by GameScreen — the widget tree disposes it.
  });
}
