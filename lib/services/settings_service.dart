import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/cube_themes.dart';

/// Persisted settings + stats for Twisty Cube. Survives app restarts.
///
/// Stores: audio toggles, the player display name, theme/sticker choices
/// (incl. custom theme face colors), difficulty tier + timed/relaxed mode,
/// Pro unlock state, and per-tier best stats.
class CubeSettings extends ChangeNotifier {
  static const _kMusic = 'twistycube_music_on';
  static const _kSfx = 'twistycube_sfx_on';
  static const _kVolume = 'twistycube_volume';
  static const _kNames = 'twistycube_player_names'; // legacy unordered key
  /// Order-safe player-name storage: a single JSON string. Android's
  /// SharedPreferences stores StringLists as an unordered StringSet, so a
  /// StringList scrambles name order on every app restart. Never use a
  /// StringList for ordered data on Android.
  static const _kNamesJson = 'twistycube_player_names_json';
  static const _kTheme = 'twistycube_theme_id';
  static const _kSticker = 'twistycube_sticker_style';
  static const _kTier = 'twistycube_tier';
  static const _kTimed = 'twistycube_timed_mode';
  static const _kSolves = 'twistycube_solves';
  static const _kGames = 'twistycube_games_played';
  static const _kBestTime = 'twistycube_best_time_ms_';
  static const _kBestMoves = 'twistycube_best_moves_';
  static const _kIsPro = 'twistycube_is_pro';
  static const _kCustomFace = 'twistycube_custom_face_';

  static const defaultNames = ['Twister'];

  /// Encode player names as one JSON string (order-preserving).
  static String encodePlayerNames(List<String> names) => jsonEncode(names);

  static String _cleanName(int i, Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultNames[i % defaultNames.length] : s;
  }

  /// Decode persisted names; falls back to defaults on missing/corrupt data.
  static List<String> decodePlayerNames(String? raw) {
    if (raw == null) return List.of(defaultNames);
    try {
      final d = jsonDecode(raw);
      if (d is List && d.length == defaultNames.length) {
        return [
          for (int i = 0; i < defaultNames.length; i++) _cleanName(i, d[i])
        ];
      }
    } catch (_) {}
    return List.of(defaultNames);
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  List<String> playerNames = List.of(defaultNames);
  String themeId = 'classic';
  int stickerStyle = 0;
  int tier = 0; // 0 = 2x2, 1 = 3x3, 2 = 4x4
  bool timedMode = false;
  int solves = 0;
  int gamesPlayed = 0;
  final List<int> bestTimeMs = [0, 0, 0]; // per tier, 0 = none yet
  final List<int> bestMoves = [0, 0, 0]; // per tier, 0 = none yet
  bool isPro = false;

  /// Custom theme face colors (ARGB ints, U,R,F,D,B,L order).
  List<int> customFaces = List.of(_defaultCustomFaces);
  static const _defaultCustomFaces = [
    0xFFF7F3EA,
    0xFFD94040,
    0xFF35A853,
    0xFFF2C230,
    0xFF2E7FD9,
    0xFFE8821E,
  ];

  CubeThemeDef get customTheme => CubeThemes.customFromColors(
      [for (final a in customFaces) Color(a)]);

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Player names: prefer the order-safe JSON key. Fall back to the legacy
    // StringList key once (one-time migration); it may already be scrambled
    // on Android, which is exactly the bug this replaces.
    final namesRaw = p.getString(_kNamesJson);
    if (namesRaw != null) {
      playerNames = decodePlayerNames(namesRaw);
    } else {
      final legacy = p.getStringList(_kNames);
      playerNames = (legacy != null && legacy.length == defaultNames.length)
          ? [
              for (int i = 0; i < defaultNames.length; i++)
                _cleanName(i, legacy[i])
            ]
          : List.of(defaultNames);
    }
    themeId = p.getString(_kTheme) ?? 'classic';
    stickerStyle = (p.getInt(_kSticker) ?? 0).clamp(0, StickerStyles.count - 1);
    tier = (p.getInt(_kTier) ?? 0).clamp(0, 2);
    timedMode = p.getBool(_kTimed) ?? false;
    solves = p.getInt(_kSolves) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    for (int i = 0; i < 3; i++) {
      bestTimeMs[i] = p.getInt('$_kBestTime$i') ?? 0;
      bestMoves[i] = p.getInt('$_kBestMoves$i') ?? 0;
    }
    isPro = p.getBool(_kIsPro) ?? false;
    for (int i = 0; i < 6; i++) {
      customFaces[i] = p.getInt('$_kCustomFace$i') ?? _defaultCustomFaces[i];
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kNamesJson, encodePlayerNames(playerNames));
    await p.remove(_kNames); // drop the legacy unordered key for good
    await p.setString(_kTheme, themeId);
    await p.setInt(_kSticker, stickerStyle);
    await p.setInt(_kTier, tier);
    await p.setBool(_kTimed, timedMode);
    await p.setInt(_kSolves, solves);
    await p.setInt(_kGames, gamesPlayed);
    for (int i = 0; i < 3; i++) {
      await p.setInt('$_kBestTime$i', bestTimeMs[i]);
      await p.setInt('$_kBestMoves$i', bestMoves[i]);
    }
    await p.setBool(_kIsPro, isPro);
    for (int i = 0; i < 6; i++) {
      await p.setInt('$_kCustomFace$i', customFaces[i]);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  /// Called after load and whenever Pro status could have changed.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || CubeThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (StickerStyles.isPro(stickerStyle)) {
      stickerStyle = 0;
      changed = true;
    }
    if (tier > 0) {
      tier = 0;
      changed = true;
    }
    if (timedMode) {
      timedMode = false;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomFace(int face, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (face < 0 || face > 5) return;
    customFaces[face] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomFaces() async {
    customFaces = List.of(_defaultCustomFaces);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  /// Save on EVERY keystroke (the UI calls this from onChanged) and commit
  /// on focus loss — never only on keyboard-done.
  Future<void> setPlayerName(int index, String name) async {
    if (index < 0 || index >= defaultNames.length) return;
    playerNames[index] = _cleanName(index, name);
    notifyListeners();
    await _save();
  }

  Future<void> commitPlayerNames() async => _save();

  Future<void> setTheme(String id) async {
    // Pro-only themes (incl. the custom theme creator) require Pro;
    // silently ignore otherwise (UI shows lock).
    if (!isPro && (id == 'custom' || CubeThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setStickerStyle(int v) async {
    v = v.clamp(0, StickerStyles.count - 1);
    if (!isPro && StickerStyles.isPro(v)) return;
    stickerStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTier(int v) async {
    v = v.clamp(0, 2);
    if (!isPro && v > 0) return; // 3x3 / 4x4 are Pro
    tier = v;
    notifyListeners();
    await _save();
  }

  Future<void> setTimedMode(bool v) async {
    if (!isPro && v) return; // timed mode is Pro
    timedMode = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished solve. [timeMs]/[moves] update per-tier bests.
  Future<void> recordSolve(
      {required int tierIndex, required int timeMs, required int moves}) async {
    solves++;
    gamesPlayed++;
    final t = tierIndex.clamp(0, 2);
    if (bestTimeMs[t] == 0 || timeMs < bestTimeMs[t]) bestTimeMs[t] = timeMs;
    if (bestMoves[t] == 0 || moves < bestMoves[t]) bestMoves[t] = moves;
    notifyListeners();
    await _save();
  }

  Future<void> recordAttempt() async {
    gamesPlayed++;
    notifyListeners();
    await _save();
  }
}
