import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const TwistyCubeApp());

class TwistyCubeApp extends StatelessWidget {
  const TwistyCubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.graffitiWall,
      title: 'Twisty Cube',
      tagline: 'Unscramble the pocket cube — tap a face, swipe to twist',
      emoji: '🎲',
      slug: 'twistycube',
      howToPlay:
          '• Tap any face of the cube to select it.\n• Swipe RIGHT to twist it clockwise, LEFT for counter-clockwise.\n• Hit Scramble for a fresh mess, then solve it!\n• Win when all 6 faces are a single color. No pressure. 😅',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) =>
          TwistyCubeScreen(players: players, callbacks: cb),
    );
  }
}
