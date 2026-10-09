import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/cube_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/cube_themes.dart';
import '../widgets/ui_bits.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const _storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.twistycube';

/// Main menu: difficulty tiers, timed/relaxed mode, player name,
/// and icon-button navigation (themes, settings, pro, share, rate).
class MenuScreen extends StatefulWidget {
  final CubeAudio audio;
  final CubeSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.settings.playerNames[0]);
    _nameFocus = FocusNode();
    // Commit on focus loss (we already save on every keystroke).
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) widget.settings.commitPlayerNames();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _play() {
    widget.audio.click();
    widget.settings.recordAttempt();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  Future<void> _share() async {
    widget.audio.click();
    await Share.share(
      'I\'m twisting cubes in Twisty Cube — can you solve the '
      'Master 4×4? $_storeUrl',
      subject: 'Twisty Cube',
    );
  }

  Future<void> _rate() async {
    widget.audio.click();
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: 'com.gameswajiha.twistycube');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = CubeThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.table,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.settings,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _header(theme),
                const SizedBox(height: 16),
                _nameField(theme),
                const SizedBox(height: 16),
                _tierPicker(theme),
                const SizedBox(height: 12),
                _modeToggle(theme),
                const SizedBox(height: 20),
                _playButton(theme),
                const SizedBox(height: 20),
                _navRow(theme),
                const SizedBox(height: 12),
                _statsStrip(theme),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(CubeThemeDef theme) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.accent, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/twistycube_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Twisty Cube',
                style: TextStyle(
                  color: theme.panel,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Twist it. Solve it. Love it.',
                style: TextStyle(
                  color: theme.panel.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (widget.settings.isPro)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF8A6D3B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _nameField(CubeThemeDef theme) {
    return PanelCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.face_rounded, color: theme.accentDark),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Your twist name',
                labelStyle: TextStyle(color: theme.inkSoft),
                border: InputBorder.none,
              ),
              maxLength: 16,
              // Save on EVERY keystroke — never only on keyboard-done.
              onChanged: (v) => widget.settings.setPlayerName(0, v),
              onSubmitted: (_) =>
                  widget.settings.commitPlayerNames(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierPicker(CubeThemeDef theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PICK YOUR CUBE',
          style: TextStyle(
            color: theme.panel.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < cubeTiers.length; i++)
              Expanded(child: _tierCard(theme, i)),
          ],
        ),
      ],
    );
  }

  Widget _tierCard(CubeThemeDef theme, int i) {
    final t = cubeTiers[i];
    final selected = widget.settings.tier == i;
    final locked = !widget.settings.isPro && i > 0;
    return GestureDetector(
      onTap: () {
        if (locked) {
          widget.audio.invalid();
          _openPro();
          return;
        }
        widget.audio.select();
        widget.settings.setTier(i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? theme.panel : theme.panel.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? theme.accent : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Mini cube glyph: 2x2 / 3x3 / 4x4 grid.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: theme.table.withValues(alpha: 0.25),
                  ),
                  child: GridView.count(
                    crossAxisCount: t.size,
                    padding: const EdgeInsets.all(6),
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (int k = 0; k < t.size * t.size; k++)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: theme.faces[k % 6],
                          ),
                        ),
                    ],
                  ),
                ),
                if (locked)
                  const Positioned(right: 0, top: 0, child: ProLock(size: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.ink,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            Text(
              t.tagline,
              style: TextStyle(color: theme.inkSoft, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeToggle(CubeThemeDef theme) {
    final timed = widget.settings.timedMode;
    final locked = !widget.settings.isPro;
    return PanelCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _modeChip(theme, Icons.spa_rounded, 'Relaxed', !timed, () {
            widget.audio.select();
            widget.settings.setTimedMode(false);
          }),
          const SizedBox(width: 8),
          _modeChip(theme, Icons.timer_rounded, 'Timed', timed, () {
            if (locked) {
              widget.audio.invalid();
              _openPro();
              return;
            }
            widget.audio.select();
            widget.settings.setTimedMode(true);
          }, locked: locked),
        ],
      ),
    );
  }

  Widget _modeChip(CubeThemeDef theme, IconData icon, String label,
      bool active, VoidCallback onTap,
      {bool locked = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? theme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? theme.accentDark : theme.inkSoft.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: active ? Colors.white : theme.inkSoft),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (locked) ...[
                const SizedBox(width: 6),
                const ProLock(size: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _playButton(CubeThemeDef theme) {
    return Column(
      children: [
        CubeIconButton(
          icon: Icons.play_arrow_rounded,
          size: 84,
          background: theme.accent,
          tooltip: 'Start twisting',
          onTap: _play,
        ),
        IconLabel('PLAY', color: theme.panel.withValues(alpha: 0.85)),
      ],
    );
  }

  Widget _navRow(CubeThemeDef theme) {
    final items = [
      (Icons.palette_rounded, 'Themes', () {
        widget.audio.click();
        _openSettings(initialTab: 1);
      }),
      (Icons.settings_rounded, 'Settings', () {
        widget.audio.click();
        _openSettings(initialTab: 0);
      }),
      (Icons.workspace_premium_rounded, 'Pro', () {
        widget.audio.click();
        _openPro();
      }),
      (Icons.share_rounded, 'Share', _share),
      (Icons.star_rounded, 'Rate', _rate),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (icon, label, fn) in items)
          Column(
            children: [
              CubeIconButton(
                icon: icon,
                size: 52,
                background: theme.panel,
                foreground: theme.accentDark,
                tooltip: label,
                onTap: fn,
              ),
              IconLabel(label.toUpperCase(),
                  color: theme.panel.withValues(alpha: 0.85)),
            ],
          ),
      ],
    );
  }

  Widget _statsStrip(CubeThemeDef theme) {
    final s = widget.settings;
    final t = cubeTiers[s.tier];
    final best = s.bestTimeMs[s.tier];
    return PanelCard(
      theme: theme,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(theme, Icons.emoji_events_rounded, 'Solves', '${s.solves}'),
          _stat(theme, Icons.grid_3x3_rounded, 'Cube', t.name.split(' ').last),
          _stat(
            theme,
            Icons.timer_rounded,
            'Best',
            best == 0 ? '—' : formatDuration(Duration(milliseconds: best)),
          ),
        ],
      ),
    );
  }

  Widget _stat(CubeThemeDef theme, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: theme.accentDark, size: 20),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              color: theme.ink, fontWeight: FontWeight.w800, fontSize: 15),
        ),
        Text(label,
            style: TextStyle(color: theme.inkSoft, fontSize: 11)),
      ],
    );
  }

  void _openSettings({int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          audio: widget.audio,
          settings: widget.settings,
          initialTab: initialTab,
        ),
      ),
    );
  }

  void _openPro() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }
}
