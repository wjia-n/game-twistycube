import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

// Validated 2x2 face-turn permutations (order-4, sexy-move order-6 verified).
// newState[j] = oldState[perm[j]]. Faces: 0=U 1=R 2=F 3=D 4=B 5=L, 4 stickers each.
const _perms = <List<int>>[
  // U
  [2, 0, 3, 1, 17, 16, 6, 7, 5, 4, 10, 11, 12, 13, 14, 15, 21, 20, 18, 19, 9, 8, 22, 23],
  // R
  [0, 9, 2, 11, 5, 7, 4, 6, 8, 13, 10, 15, 12, 18, 14, 16, 3, 17, 1, 19, 20, 21, 22, 23],
  // F
  [0, 1, 22, 20, 4, 2, 6, 3, 10, 8, 11, 9, 7, 5, 14, 15, 16, 17, 18, 19, 12, 21, 13, 23],
  // D
  [0, 1, 2, 3, 4, 5, 11, 10, 8, 9, 23, 22, 14, 12, 15, 13, 16, 17, 7, 6, 20, 21, 19, 18],
  // B
  [19, 1, 17, 3, 4, 5, 6, 7, 0, 9, 2, 11, 8, 13, 10, 15, 16, 14, 18, 12, 21, 23, 20, 22],
  // L
  [4, 6, 2, 3, 15, 5, 14, 7, 8, 9, 10, 11, 12, 13, 21, 23, 18, 16, 19, 17, 20, 1, 22, 0],
];
const _faceNames = ['U', 'R', 'F', 'D', 'B', 'L'];
const _faceColors = <Color>[
  Color(0xFFF5F5F7), // U white
  Color(0xFFE5484D), // R red
  Color(0xFF30D158), // F green
  Color(0xFFFFD60A), // D yellow
  Color(0xFF0A84FF), // B blue
  Color(0xFFFF9F2E), // L orange
];

class TwistyCubeScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const TwistyCubeScreen(
      {super.key, required this.players, required this.callbacks});

  @override
  State<TwistyCubeScreen> createState() => _TwistyCubeScreenState();
}

class _TwistyCubeScreenState extends State<TwistyCubeScreen> {
  final _rnd = Random();
  List<int> _st = List.generate(24, (i) => i ~/ 4);
  int _selected = 2; // F
  int _moves = 0;
  bool _over = false;
  bool _scrambled = false;

  List<int> _inverse(List<int> p) {
    final inv = List<int>.filled(24, 0);
    for (int j = 0; j < 24; j++) {
      inv[p[j]] = j;
    }
    return inv;
  }

  void _applyPerm(List<int> perm) {
    setState(() {
      _st = [for (int j = 0; j < 24; j++) _st[perm[j]]];
      _moves++;
    });
    Sfx.move();
    _checkWin();
  }

  void _twist(bool clockwise) {
    if (_over) return;
    _applyPerm(clockwise ? _perms[_selected] : _inverse(_perms[_selected]));
  }

  void _scramble() {
    setState(() {
      for (int n = 0; n < 22; n++) {
        final p = _perms[_rnd.nextInt(6)];
        final useInv = _rnd.nextBool();
        final perm = useInv ? _inverse(p) : p;
        _st = [for (int j = 0; j < 24; j++) _st[perm[j]]];
      }
      _moves = 0;
      _over = false;
      _scrambled = true;
    });
    Sfx.click();
  }

  bool _isSolved() {
    for (int f = 0; f < 6; f++) {
      final c = _st[f * 4];
      for (int k = 1; k < 4; k++) {
        if (_st[f * 4 + k] != c) return false;
      }
    }
    return true;
  }

  void _checkWin() {
    if (_over || !_scrambled || !_isSolved()) return;
    setState(() => _over = true);
    Sfx.win();
    widget.players.first.score = max(0, 1000 - _moves * 10);
    widget.callbacks.refreshHud();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      widget.callbacks.finish(
        headline: '🎲 Cube conquered in $_moves moves!',
        subline: 'Pocket-sized genius. The 3x3 fears you now.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _over
                ? 'Solved! Absolute legend. 🏆'
                : _scrambled
                    ? 'Moves: $_moves — tap a face, then swipe ◀ ▶ to twist'
                    : 'Hit Scramble to begin your quest 👇',
            style: TextStyle(color: theme.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v.abs() < 200) return;
                _twist(v > 0);
              },
              child: _CubeNet(
                st: _st,
                selected: _selected,
                theme: theme,
                onFaceTap: (f) {
                  if (_over) return;
                  setState(() => _selected = f);
                  Sfx.tap();
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WajihaButton(
                  label: 'Scramble 🌀', emoji: '', onTap: _scramble),
              const SizedBox(width: 12),
              WajihaButton(
                  label: '⟲ CCW',
                  emoji: '',
                  onTap: () => _twist(false),
                  primary: false),
              const SizedBox(width: 12),
              WajihaButton(
                  label: 'CW ⟳', emoji: '', onTap: () => _twist(true)),
            ],
          ),
        ),
      ],
    );
  }
}

class _CubeNet extends StatelessWidget {
  final List<int> st;
  final int selected;
  final GameTheme theme;
  final void Function(int) onFaceTap;
  const _CubeNet(
      {required this.st,
      required this.selected,
      required this.theme,
      required this.onFaceTap});

  @override
  Widget build(BuildContext context) {
    // Net layout: face -> (col, row) in a 4x3 grid of faces
    const pos = {0: (1, 0), 5: (0, 1), 2: (1, 1), 1: (2, 1), 4: (3, 1), 3: (1, 2)};
    return LayoutBuilder(builder: (ctx, c) {
      final faceSize = min(c.maxWidth / 4.4, c.maxHeight / 3.4);
      final cell = faceSize / 2;
      return SizedBox(
        width: faceSize * 4.4,
        height: faceSize * 3.4,
        child: Stack(
          children: [
            for (final e in pos.entries)
              Positioned(
                left: e.value.$1 * faceSize + faceSize * 0.2,
                top: e.value.$2 * faceSize + faceSize * 0.2,
                child: _Face(
                  face: e.key,
                  st: st,
                  cell: cell,
                  selected: selected == e.key,
                  theme: theme,
                  onTap: () => onFaceTap(e.key),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _Face extends StatelessWidget {
  final int face;
  final List<int> st;
  final double cell;
  final bool selected;
  final GameTheme theme;
  final VoidCallback onTap;
  const _Face(
      {required this.face,
      required this.st,
      required this.cell,
      required this.selected,
      required this.theme,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? theme.primary : theme.muted.withValues(alpha: 0.35),
              width: selected ? 3 : 1.5),
          color: selected ? theme.primary.withValues(alpha: 0.12) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int r = 0; r < 2; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int c = 0; c < 2; c++)
                    Container(
                      width: cell,
                      height: cell,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _faceColors[st[face * 4 + r * 2 + c]],
                            _faceColors[st[face * 4 + r * 2 + c]]
                                .withValues(alpha: 0.72),
                          ],
                        ),
                        border: Border.all(color: Colors.black26, width: 1),
                      ),
                    ),
                ],
              ),
            Text(_faceNames[face],
                style: TextStyle(
                    color: theme.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
