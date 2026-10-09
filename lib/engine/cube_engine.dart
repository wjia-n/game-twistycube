import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Twisty Cube engine: generalized NxN twisty-cube logic with an
/// engine-owned state machine and a watchdog. No UI timers drive gameplay.
///
/// Faces: 0=U 1=R 2=F 3=D 4=B 5=L. Sticker index = face*n*n + row*n + col.
/// Face-turn permutations are DERIVED from 3D coordinate rotation
/// (clockwise viewed from outside the face = -90 degrees about the outward
/// normal) and validated by test/cube_engine_test.dart:
/// every turn has order 4, inverse sequences re-solve, and the classic
/// sexy move (R U R' U') has order 6 for n = 2, 3, 4.
enum CubePhase { idle, scrambling, ready, turning, solved }

/// Difficulty tiers: cube size + scramble depth + timed-mode par.
class CubeTier {
  final int size;
  final String name;
  final String tagline;
  final int scrambleDepth;
  final int timeLimitSecs; // timed mode
  final int parMoves; // 3-star bar
  final int parSecs; // 3-star bar
  const CubeTier({
    required this.size,
    required this.name,
    required this.tagline,
    required this.scrambleDepth,
    required this.timeLimitSecs,
    required this.parMoves,
    required this.parSecs,
  });
}

const cubeTiers = [
  CubeTier(
    size: 2,
    name: 'Pocket 2×2',
    tagline: 'Learn the twist',
    scrambleDepth: 12,
    timeLimitSecs: 180,
    parMoves: 30,
    parSecs: 90,
  ),
  CubeTier(
    size: 3,
    name: 'Classic 3×3',
    tagline: 'The real deal',
    scrambleDepth: 25,
    timeLimitSecs: 600,
    parMoves: 140,
    parSecs: 360,
  ),
  CubeTier(
    size: 4,
    name: 'Master 4×4',
    tagline: 'For cube wizards',
    scrambleDepth: 40,
    timeLimitSecs: 1200,
    parMoves: 300,
    parSecs: 720,
  ),
];

/// Doubled-integer sticker coordinates. Centers live on the odd lattice,
/// face planes at +/-n. Shared with the painter so animation and logic
/// always agree on geometry.
List<int> stickerCoords(int index, int n) {
  final g = n - 1;
  final f = index ~/ (n * n);
  final rc = index % (n * n);
  final r = rc ~/ n;
  final c = rc % n;
  switch (f) {
    case 0:
      return [2 * c - g, n, 2 * r - g]; // U
    case 3:
      return [2 * c - g, -n, g - 2 * r]; // D
    case 2:
      return [2 * c - g, g - 2 * r, n]; // F
    case 4:
      return [g - 2 * c, g - 2 * r, -n]; // B
    case 1:
      return [n, g - 2 * r, g - 2 * c]; // R
    default:
      return [-n, g - 2 * r, 2 * c - g]; // L
  }
}

/// Outward normal axis (0=x,1=y,2=z) and sign per face.
const _faceAxis = [1, 0, 2, 1, 2, 0];
const _faceSign = [1, 1, 1, -1, -1, -1];

/// Cached turn permutations per cube size. perm[face] is the clockwise
/// permutation: newState[j] = oldState[perm[j]].
final Map<int, List<List<int>>> _permCache = {};

List<List<int>> turnPermutations(int n) {
  return _permCache.putIfAbsent(n, () {
    final count = 6 * n * n;
    final coords = [for (int i = 0; i < count; i++) stickerCoords(i, n)];
    final indexOf = <String, int>{
      for (int i = 0; i < count; i++) coords[i].join(','): i,
    };
    final perms = <List<int>>[];
    for (int f = 0; f < 6; f++) {
      final ax = _faceAxis[f];
      final s = _faceSign[f];
      final a = (ax + 1) % 3;
      final b = (ax + 2) % 3;
      final perm = List<int>.filled(count, 0);
      for (int i = 0; i < count; i++) {
        final p = [coords[i][0], coords[i][1], coords[i][2]];
        if (s * p[ax] >= n - 1) {
          // On the turning layer: rotate -90 deg about the signed axis
          // (clockwise viewed from outside the face).
          int pa, pb;
          if (s == 1) {
            pa = p[b];
            pb = -p[a];
          } else {
            pa = -p[b];
            pb = p[a];
          }
          p[a] = pa;
          p[b] = pb;
        }
        perm[indexOf[p.join(',')]!] = i;
      }
      perms.add(perm);
    }
    return perms;
  });
}

/// True when every face is a single color.
bool isSolvedState(List<int> stickers, int n) {
  for (int f = 0; f < 6; f++) {
    for (int i = 0; i < n * n; i++) {
      if (stickers[f * n * n + i] != f) return false;
    }
  }
  return true;
}

class CubeEngine extends ChangeNotifier {
  CubeEngine({required int tier}) : _tierIndex = tier {
    _rng = Random();
    _newCube();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) => _watch());
  }

  final _permsFor = <int, List<List<int>>>{};
  late Random _rng;
  int _tierIndex;
  int get tierIndex => _tierIndex;
  CubeTier get tier => cubeTiers[_tierIndex];
  int get size => tier.size;

  List<int> stickers = [];
  CubePhase phase = CubePhase.idle;
  int moves = 0;
  bool timedMode = false;
  bool timedOut = false;

  // Turn-animation handshake: the UI reads these while phase == turning.
  int animFace = 2;
  bool animClockwise = true;

  // Stopwatch for timed/relaxed play.
  final Stopwatch _clock = Stopwatch();
  Duration get elapsed => _clock.elapsed;

  Timer? _scrambleTimer;
  Timer? _watchdog;
  DateTime _phaseEnteredAt = DateTime.now();
  int _scrambleLeft = 0;
  int _lastFace = -1;
  CubePhase? _pausedFrom;
  bool _disposed = false;

  List<List<int>> get _perms =>
      _permsFor.putIfAbsent(size, () => turnPermutations(size));

  void _newCube() {
    final n = size;
    stickers = [for (int i = 0; i < 6 * n * n; i++) i ~/ (n * n)];
    moves = 0;
    timedOut = false;
    _clock.reset();
  }

  void _setPhase(CubePhase p) {
    phase = p;
    _phaseEnteredAt = DateTime.now();
    notifyListeners();
  }

  // ------------------------------------------------------------ game flow
  /// Start a fresh scramble with animation. Engine-owned timer applies one
  /// move per tick; the UI animates each step from [animFace]/[animClockwise].
  void startScramble({bool timed = false}) {
    _scrambleTimer?.cancel();
    _pausedFrom = null; // a fresh scramble clears any paused state
    timedMode = timed;
    _newCube();
    _scrambleLeft = tier.scrambleDepth;
    _lastFace = -1;
    _setPhase(CubePhase.scrambling);
    _scrambleTimer =
        Timer.periodic(const Duration(milliseconds: 130), (_) => _stepScramble());
  }

  void _stepScramble() {
    if (_disposed || phase != CubePhase.scrambling) {
      _scrambleTimer?.cancel();
      return;
    }
    if (_scrambleLeft <= 0) {
      _scrambleTimer?.cancel();
      // Never hand the player an already-solved cube.
      if (isSolvedState(stickers, size)) {
        _scrambleLeft = 3;
        _scrambleTimer = Timer.periodic(
            const Duration(milliseconds: 130), (_) => _stepScramble());
        return;
      }
      moves = 0;
      _clock.reset();
      _clock.start();
      _setPhase(CubePhase.ready);
      return;
    }
    _scrambleLeft--;
    // Avoid immediately undoing the previous move — better scrambles.
    int f;
    do {
      f = _rng.nextInt(6);
    } while (f == _lastFace && _rng.nextBool());
    _lastFace = f;
    final cw = _rng.nextBool();
    _applyPerm(f, cw);
    animFace = f;
    animClockwise = cw;
    notifyListeners();
  }

  void _applyPerm(int face, bool clockwise) {
    final perm = _perms[face];
    final n = size * size * 6;
    final next = List<int>.filled(n, 0);
    if (clockwise) {
      for (int j = 0; j < n; j++) {
        next[j] = stickers[perm[j]];
      }
    } else {
      for (int j = 0; j < n; j++) {
        next[perm[j]] = stickers[j];
      }
    }
    stickers = next;
  }

  /// Request a face turn. Returns false when the engine is not accepting
  /// input (mid-animation, scrambling, solved, paused). The caller plays the
  /// twist SFX and animates using [animFace]/[animClockwise], then calls
  /// [finishTurn] when the animation completes.
  bool turn(int face, bool clockwise) {
    if (phase != CubePhase.ready) return false;
    if (face < 0 || face > 5) return false;
    animFace = face;
    animClockwise = clockwise;
    _applyPerm(face, clockwise);
    moves++;
    _setPhase(CubePhase.turning);
    return true;
  }

  /// Called by the UI when the turn animation finishes. Settles the move,
  /// detects the solve, and returns the engine to ready. The watchdog also
  /// calls this if the UI ever fails to — stuck states are impossible.
  void finishTurn() {
    if (phase != CubePhase.turning) return;
    if (isSolvedState(stickers, size)) {
      _clock.stop();
      _setPhase(CubePhase.solved);
    } else {
      _setPhase(CubePhase.ready);
    }
  }

  /// Undo is not a legal cube action mid-solve; reset re-scrambles instead.
  void reset() => startScramble(timed: timedMode);

  void setTier(int tierIndex) {
    _tierIndex = tierIndex.clamp(0, 2);
    _scrambleTimer?.cancel();
    _newCube();
    _setPhase(CubePhase.idle);
  }

  void pause() {
    if (phase == CubePhase.ready || phase == CubePhase.turning) {
      _pausedFrom = phase;
      _clock.stop();
      _setPhase(CubePhase.idle);
    }
  }

  void resume() {
    if (_pausedFrom != null) {
      final back = _pausedFrom!;
      _pausedFrom = null;
      if (timedMode || moves > 0) _clock.start();
      _setPhase(back == CubePhase.turning ? CubePhase.ready : back);
    }
  }

  bool get isPaused => _pausedFrom != null;

  // ------------------------------------------------------------- watchdog
  /// Recovers any phase found without forward progress: an unfinished turn
  /// is settled, a stalled scramble is aborted back to idle. Runs every
  /// second; also enforces the timed-mode clock.
  void _watch() {
    if (_disposed) return;
    final stuckFor = DateTime.now().difference(_phaseEnteredAt);
    if (phase == CubePhase.turning && stuckFor > const Duration(seconds: 4)) {
      // UI never called finishTurn — settle the move ourselves.
      finishTurn();
    } else if (phase == CubePhase.scrambling &&
        stuckFor > const Duration(seconds: 30)) {
      _scrambleTimer?.cancel();
      _setPhase(CubePhase.idle);
    }
    if (timedMode &&
        !timedOut &&
        phase != CubePhase.solved &&
        phase != CubePhase.idle &&
        _clock.elapsed.inSeconds >= tier.timeLimitSecs) {
      timedOut = true;
      _clock.stop();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scrambleTimer?.cancel();
    _watchdog?.cancel();
    _clock.stop();
    super.dispose();
  }
}
