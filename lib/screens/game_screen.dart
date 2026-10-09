import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/cube_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/cube_themes.dart';
import '../widgets/cube_view.dart';
import '../widgets/ui_bits.dart';

const _faceLetters = ['U', 'R', 'F', 'D', 'B', 'L'];
const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.twistycube';

/// Active play: the pseudo-3D cube, HUD (timer + moves), face chips,
/// icon turn controls, scramble/reset, pause, and win/lose dialogs.
///
/// The engine owns the state machine; this screen only renders it and
/// forwards input. No turn is ever silently auto-played or auto-resolved.
class GameScreen extends StatefulWidget {
  final CubeAudio audio;
  final CubeSettings settings;
  const GameScreen({super.key, required this.audio, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final CubeEngine _engine;
  int _selectedFace = 2; // F
  final ValueNotifier<Duration> _clockTick = ValueNotifier(Duration.zero);
  Timer? _tickTimer;
  bool _winShown = false;
  bool _loseShown = false;
  bool _dialogOpen = false;
  int _lastTickSlot = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = CubeEngine(tier: widget.settings.tier);
    _engine.addListener(_onEngine);
    _tickTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      _clockTick.value = _engine.elapsed;
      // Countdown ticks in the last 10 seconds of timed mode.
      if (widget.settings.timedMode &&
          _engine.phase != CubePhase.solved &&
          !_engine.timedOut) {
        final remain =
            _engine.tier.timeLimitSecs - _engine.elapsed.inSeconds;
        if (remain <= 10 && remain > 0) {
          final whole = _engine.elapsed.inMilliseconds ~/ 250;
          if (whole != _lastTickSlot) {
            _lastTickSlot = whole;
            widget.audio.tick();
          }
        }
      }
    });
    // Start the animated scramble after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.audio.startGameMusic();
      widget.audio.gameStart();
      _engine.startScramble(timed: widget.settings.timedMode);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.removeListener(_onEngine);
    _tickTimer?.cancel();
    _clockTick.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Freeze the engine (and its clock) when backgrounded; the audio
    // service handles music pause/resume app-wide.
    if (state == AppLifecycleState.paused) {
      _engine.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_dialogOpen) return; // stay paused under dialogs
      _engine.resume();
    }
  }

  void _onEngine() {
    if (!mounted) return;
    if (_engine.phase == CubePhase.solved && !_winShown) {
      _winShown = true;
      _onWin();
    } else if (_engine.timedOut && !_loseShown) {
      _loseShown = true;
      _onLose();
    }
  }

  void _doTurn(bool clockwise) {
    if (_engine.turn(_selectedFace, clockwise)) {
      if (clockwise) {
        widget.audio.twist();
      } else {
        widget.audio.twistBack();
      }
    } else {
      widget.audio.invalid();
    }
  }

  void _selectFace(int f) {
    if (f == _selectedFace) return;
    widget.audio.select();
    setState(() => _selectedFace = f);
  }

  Future<void> _onWin() async {
    widget.audio.win();
    final tierIdx = _engine.tierIndex;
    final ms = _engine.elapsed.inMilliseconds;
    await widget.settings.recordSolve(
      tierIndex: tierIdx,
      timeMs: ms,
      moves: _engine.moves,
    );
    // Ask for a rating after the player's second solve.
    if (widget.settings.solves == 2) {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) await review.requestReview();
      } catch (_) {}
    }
    if (!mounted) return;
    _showWinDialog();
  }

  Future<void> _onLose() async {
    widget.audio.lose();
    if (!mounted) return;
    _dialogOpen = true;
    _engine.pause();
    final theme = _theme();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        theme: theme,
        title: 'Time\'s up!',
        subtitle:
            'The ${cubeTiers[_engine.tierIndex].name} beat you this time. '
            'Give it another twist?',
        stars: 0,
        stats: [
          'Moves: ${_engine.moves}',
          'Best: ${_bestLine()}',
        ],
        actions: [
          _DialogAction(
              icon: Icons.refresh_rounded, label: 'RETRY', onTap: _retry),
          _DialogAction(
              icon: Icons.home_rounded, label: 'MENU', onTap: _quitToMenu),
        ],
      ),
    );
    _dialogOpen = false;
  }

  void _showWinDialog() {
    _dialogOpen = true;
    final theme = _theme();
    final stars = _stars();
    final name = widget.settings.playerNames[0];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        theme: theme,
        title: 'Solved!',
        subtitle: 'Brilliant twisting, $name!',
        stars: stars,
        stats: [
          'Time: ${formatDuration(_engine.elapsed)}',
          'Moves: ${_engine.moves}',
          'Best: ${_bestLine()}',
        ],
        actions: [
          _DialogAction(
              icon: Icons.refresh_rounded, label: 'AGAIN', onTap: _retry),
          _DialogAction(
              icon: Icons.share_rounded, label: 'SHARE', onTap: _shareWin),
          _DialogAction(
              icon: Icons.home_rounded, label: 'MENU', onTap: _quitToMenu),
        ],
      ),
    ).then((_) => _dialogOpen = false);
  }

  int _stars() {
    final t = _engine.tier;
    final secs = _engine.elapsed.inSeconds;
    final timeScore = secs <= t.parSecs
        ? 2
        : (secs <= t.parSecs * 2 ? 1 : 0);
    final moveScore = _engine.moves <= t.parMoves ? 1 : 0;
    return (1 + timeScore + moveScore).clamp(1, 3);
  }

  String _bestLine() {
    final i = _engine.tierIndex;
    final bt = widget.settings.bestTimeMs[i];
    final bm = widget.settings.bestMoves[i];
    if (bt == 0) return '—';
    return '${formatDuration(Duration(milliseconds: bt))} · $bm moves';
  }

  void _retry() {
    Navigator.of(context).pop();
    widget.audio.click();
    setState(() {
      _winShown = false;
      _loseShown = false;
    });
    widget.settings.recordAttempt();
    _engine.startScramble(timed: widget.settings.timedMode);
  }

  void _quitToMenu() {
    Navigator.of(context).pop();
    widget.audio.click();
    Navigator.of(context).pop();
    widget.audio.startMenuMusic();
  }

  Future<void> _shareWin() async {
    widget.audio.click();
    final t = cubeTiers[_engine.tierIndex];
    await Share.share(
      'I just solved the ${t.name} cube in Twisty Cube in '
      '${formatDuration(_engine.elapsed)} with ${_engine.moves} moves! '
      'Can you beat me? $_storeUrl',
      subject: 'Twisty Cube',
    );
  }

  void _pauseGame() {
    widget.audio.click();
    _engine.pause();
    _dialogOpen = true;
    final theme = _theme();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        theme: theme,
        title: 'Paused',
        subtitle: 'Take a breather. The cube isn\'t going anywhere.',
        stars: 0,
        showStars: false,
        stats: [
          'Time: ${formatDuration(_engine.elapsed)}',
          'Moves: ${_engine.moves}',
        ],
        actions: [
          _DialogAction(
              icon: Icons.play_arrow_rounded,
              label: 'RESUME',
              onTap: () {
                Navigator.of(context).pop();
                widget.audio.click();
                _engine.resume();
              }),
          _DialogAction(
              icon: Icons.refresh_rounded, label: 'RESTART', onTap: _retry),
          _DialogAction(
              icon: Icons.home_rounded, label: 'QUIT', onTap: _quitToMenu),
        ],
      ),
    ).then((_) {
      _dialogOpen = false;
      if (mounted && !_winShown && !_loseShown) _engine.resume();
    });
  }

  CubeThemeDef _theme() => CubeThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  Widget build(BuildContext context) {
    final theme = _theme();
    return Scaffold(
      backgroundColor: theme.table,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _engine,
          builder: (_, _) => Column(
            children: [
              _header(theme),
              _hud(theme),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CubeView(
                    engine: _engine,
                    theme: theme,
                    stickerStyle: widget.settings.stickerStyle,
                    selectedFace: _selectedFace,
                    onSelectFace: _selectFace,
                  ),
                ),
              ),
              _faceChips(theme),
              const SizedBox(height: 8),
              _turnControls(theme),
              const SizedBox(height: 8),
              _bottomRow(theme),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(CubeThemeDef theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          CubeIconButton(
            icon: Icons.arrow_back_rounded,
            size: 44,
            background: theme.panel,
            foreground: theme.accentDark,
            tooltip: 'Back',
            onTap: () {
              widget.audio.click();
              Navigator.of(context).pop();
              widget.audio.startMenuMusic();
            },
          ),
          Expanded(
            child: Text(
              cubeTiers[_engine.tierIndex].name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.panel,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          CubeIconButton(
            icon: Icons.pause_rounded,
            size: 44,
            background: theme.panel,
            foreground: theme.accentDark,
            tooltip: 'Pause',
            onTap: (_engine.phase == CubePhase.ready ||
                    _engine.phase == CubePhase.turning)
                ? _pauseGame
                : null,
          ),
        ],
      ),
    );
  }

  Widget _hud(CubeThemeDef theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ValueListenableBuilder<Duration>(
            valueListenable: _clockTick,
            builder: (_, d, _) {
              final timed = widget.settings.timedMode;
              final limit = _engine.tier.timeLimitSecs;
              final text = timed
                  ? formatDuration(
                      Duration(seconds: (limit - d.inSeconds).clamp(0, limit)))
                  : formatDuration(d);
              final urgent =
                  timed && (limit - d.inSeconds) <= 30;
              return _hudChip(
                theme,
                timed ? Icons.timer_rounded : Icons.schedule_rounded,
                text,
                urgent ? const Color(0xFFB03A2E) : null,
              );
            },
          ),
          _hudChip(theme, Icons.touch_app_rounded, '${_engine.moves} moves'),
          _hudChip(
            theme,
            Icons.grid_3x3_rounded,
            _phaseLabel(),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(CubeThemeDef theme, IconData icon, String text,
      [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? theme.accentDark),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color ?? theme.ink,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel() {
    switch (_engine.phase) {
      case CubePhase.idle:
        return _engine.isPaused ? 'Paused' : 'Ready';
      case CubePhase.scrambling:
        return 'Scrambling…';
      case CubePhase.ready:
        return 'Your move';
      case CubePhase.turning:
        return 'Twisting…';
      case CubePhase.solved:
        return 'Solved!';
    }
  }

  Widget _faceChips(CubeThemeDef theme) {
    return SizedBox(
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int f = 0; f < 6; f++)
            GestureDetector(
              onTap: () => _selectFace(f),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.faces[f],
                        border: Border.all(
                          color: f == _selectedFace
                              ? theme.accent
                              : Colors.black.withValues(alpha: 0.25),
                          width: f == _selectedFace ? 3.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            offset: const Offset(0, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _faceLetters[f],
                      style: TextStyle(
                        color: f == _selectedFace
                            ? theme.accent
                            : theme.panel.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _turnControls(CubeThemeDef theme) {
    final canTurn = _engine.phase == CubePhase.ready;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            CubeIconButton(
              icon: Icons.rotate_left_rounded,
              size: 64,
              background: theme.panel,
              foreground: theme.accentDark,
              tooltip: 'Twist ${_faceLetters[_selectedFace]} counter-clockwise',
              onTap: canTurn ? () => _doTurn(false) : null,
            ),
            IconLabel('TWIST ◀',
                color: theme.panel.withValues(alpha: 0.85)),
          ],
        ),
        const SizedBox(width: 28),
        Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.faces[_selectedFace],
                border: Border.all(color: theme.accent, width: 3),
              ),
              child: Center(
                child: Text(
                  _faceLetters[_selectedFace],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54, offset: Offset(1, 1))
                    ],
                  ),
                ),
              ),
            ),
            IconLabel('FACE', color: theme.panel.withValues(alpha: 0.85)),
          ],
        ),
        const SizedBox(width: 28),
        Column(
          children: [
            CubeIconButton(
              icon: Icons.rotate_right_rounded,
              size: 64,
              background: theme.panel,
              foreground: theme.accentDark,
              tooltip: 'Twist ${_faceLetters[_selectedFace]} clockwise',
              onTap: canTurn ? () => _doTurn(true) : null,
            ),
            IconLabel('TWIST ▶',
                color: theme.panel.withValues(alpha: 0.85)),
          ],
        ),
      ],
    );
  }

  Widget _bottomRow(CubeThemeDef theme) {
    final busy = _engine.phase == CubePhase.scrambling;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            CubeIconButton(
              icon: Icons.shuffle_rounded,
              size: 50,
              background: theme.panel,
              foreground: theme.accentDark,
              tooltip: 'New scramble',
              onTap: busy
                  ? null
                  : () {
                      widget.audio.scramble();
                      _winShown = false;
                      _loseShown = false;
                      widget.settings.recordAttempt();
                      _engine.startScramble(
                          timed: widget.settings.timedMode);
                    },
            ),
            IconLabel('SCRAMBLE',
                color: theme.panel.withValues(alpha: 0.85)),
          ],
        ),
        const SizedBox(width: 24),
        Column(
          children: [
            CubeIconButton(
              icon: Icons.lightbulb_outline_rounded,
              size: 50,
              background: theme.panel,
              foreground: theme.accentDark,
              tooltip: 'How to play',
              onTap: () {
                widget.audio.click();
                _showHelp(theme);
              },
            ),
            IconLabel('HELP', color: theme.panel.withValues(alpha: 0.85)),
          ],
        ),
      ],
    );
  }

  void _showHelp(CubeThemeDef theme) {
    showDialog(
      context: context,
      builder: (_) => _ResultDialog(
        theme: theme,
        title: 'How to twist',
        subtitle: 'Tap a sticker — or a face chip — to pick a face. '
            'Hit the twist buttons to turn it. Drag the cube to look around. '
            'Solve all six faces to win!',
        stars: 0,
        showStars: false,
        stats: const [],
        actions: [
          _DialogAction(
            icon: Icons.check_rounded,
            label: 'GOT IT',
            onTap: () {
              Navigator.of(context).pop();
              widget.audio.click();
            },
          ),
        ],
      ),
    );
  }
}

class _DialogAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _DialogAction(
      {required this.icon, required this.label, required this.onTap});
}

class _ResultDialog extends StatelessWidget {
  final CubeThemeDef theme;
  final String title;
  final String subtitle;
  final int stars;
  final bool showStars;
  final List<String> stats;
  final List<_DialogAction> actions;

  const _ResultDialog({
    required this.theme,
    required this.title,
    required this.subtitle,
    this.stars = 0,
    this.showStars = true,
    this.stats = const [],
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: PanelCard(
        theme: theme,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                  color: theme.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.inkSoft, fontSize: 14),
            ),
            if (showStars) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: i < stars
                            ? const Color(0xFFE3A82B)
                            : theme.inkSoft.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final s in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    s,
                    style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final a in actions)
                  Column(
                    children: [
                      CubeIconButton(
                        icon: a.icon,
                        size: 54,
                        background: theme.accent,
                        onTap: a.onTap,
                      ),
                      IconLabel(a.label, color: theme.inkSoft),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
