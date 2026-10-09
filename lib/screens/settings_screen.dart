import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/cube_themes.dart';
import '../widgets/ui_bits.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Settings: audio toggles + volume, player name, sticker styles.
/// Second tab: the theme picker (12 themes + custom creator).
class SettingsScreen extends StatefulWidget {
  final CubeAudio audio;
  final CubeSettings settings;
  final int initialTab;
  const SettingsScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.initialTab = 0,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
    _nameCtrl =
        TextEditingController(text: widget.settings.playerNames[0]);
    _nameFocus = FocusNode();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) widget.settings.commitPlayerNames();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _applyAudio() {
    widget.audio.configure(
      musicOn: widget.settings.musicOn,
      sfxOn: widget.settings.sfxOn,
      volume: widget.settings.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CubeThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.table,
      appBar: AppBar(
        backgroundColor: theme.table,
        foregroundColor: theme.panel,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: theme.accent,
          unselectedLabelColor: theme.panel.withValues(alpha: 0.6),
          indicatorColor: theme.accent,
          tabs: const [
            Tab(icon: Icon(Icons.tune_rounded), text: 'GAME'),
            Tab(icon: Icon(Icons.palette_rounded), text: 'THEMES'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (_, _) => TabBarView(
          controller: _tabs,
          children: [
            _gameTab(theme),
            _themesTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _gameTab(CubeThemeDef theme) {
    final s = widget.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PanelCard(
            theme: theme,
            child: Column(
              children: [
                _switchRow(
                  theme,
                  Icons.music_note_rounded,
                  'Music',
                  s.musicOn,
                  (v) {
                    s.setMusic(v);
                    _applyAudio();
                    widget.audio.click();
                  },
                ),
                _switchRow(
                  theme,
                  Icons.volume_up_rounded,
                  'Sound effects',
                  s.sfxOn,
                  (v) {
                    s.setSfx(v);
                    _applyAudio();
                    widget.audio.click();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.graphic_eq_rounded,
                        color: theme.accentDark),
                    Expanded(
                      child: Slider(
                        value: s.volume,
                        activeColor: theme.accent,
                        onChanged: (v) {
                          s.setVolume(v);
                          _applyAudio();
                        },
                        onChangeEnd: (_) => widget.audio.click(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PanelCard(
            theme: theme,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.face_rounded, color: theme.accentDark),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    focusNode: _nameFocus,
                    style: TextStyle(
                        color: theme.ink, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: 'Your twist name',
                      labelStyle: TextStyle(color: theme.inkSoft),
                      border: InputBorder.none,
                    ),
                    maxLength: 16,
                    // Save on EVERY keystroke — never only on keyboard-done.
                    onChanged: (v) => s.setPlayerName(0, v),
                    onSubmitted: (_) => s.commitPlayerNames(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PanelCard(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STICKER STYLE',
                    style: TextStyle(
                        color: theme.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (int i = 0; i < StickerStyles.count; i++)
                      _styleChip(theme, i),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(CubeThemeDef theme, IconData icon, String label,
      bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Icon(icon, color: theme.accentDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ),
        Switch(
          value: value,
          activeColor: theme.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _styleChip(CubeThemeDef theme, int i) {
    final s = widget.settings;
    final selected = s.stickerStyle == i;
    final locked = !s.isPro && StickerStyles.isPro(i);
    return GestureDetector(
      onTap: () {
        if (locked) {
          widget.audio.invalid();
          _openPro();
          return;
        }
        widget.audio.select();
        s.setStickerStyle(i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? theme.accent : theme.table.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.accentDark : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              StickerStyles.names[i],
              style: TextStyle(
                color: selected ? Colors.white : theme.ink,
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
    );
  }

  Widget _themesTab(CubeThemeDef theme) {
    final s = widget.settings;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              for (final t in CubeThemes.all) _themeCard(theme, t),
              _customCard(theme),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pro unlocks every theme, sticker style, the 3×3 & 4×4 cubes, '
            'timed mode and the custom theme creator.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: theme.panel.withValues(alpha: 0.75), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _themeCard(CubeThemeDef theme, CubeThemeDef t) {
    final s = widget.settings;
    final selected = s.themeId == t.id;
    final locked = !s.isPro && t.isPro;
    return GestureDetector(
      onTap: () {
        if (locked) {
          widget.audio.invalid();
          _openPro();
          return;
        }
        widget.audio.select();
        s.setTheme(t.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? theme.accent : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  for (int i = 0; i < 6; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: t.faces[i],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: Colors.black.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
                if (locked) const ProLock(size: 12),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: theme.accent, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _customCard(CubeThemeDef theme) {
    final s = widget.settings;
    final selected = s.themeId == 'custom';
    final locked = !s.isPro;
    return GestureDetector(
      onTap: () {
        if (locked) {
          widget.audio.invalid();
          _openPro();
          return;
        }
        widget.audio.click();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomThemeScreen(
              audio: widget.audio,
              settings: widget.settings,
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? theme.accent : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.brush_rounded, color: theme.accentDark, size: 34),
            const SizedBox(height: 6),
            Text(
              'My Creation',
              style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
            const SizedBox(height: 2),
            if (locked)
              const ProLock(size: 12)
            else
              Text(
                selected ? 'Active' : 'Design your own',
                style: TextStyle(color: theme.inkSoft, fontSize: 11),
              ),
          ],
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
