import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/cube_themes.dart';
import '../widgets/ui_bits.dart';

const _faceNames = ['Up', 'Right', 'Front', 'Down', 'Back', 'Left'];
const _faceLetters = ['U', 'R', 'F', 'D', 'B', 'L'];

/// A tasteful, toy-like palette — no neon.
const _palette = [
  0xFFF7F3EA, 0xFFE8DCC8, 0xFFD9C9A8,
  0xFFD94040, 0xFFA8452F, 0xFF8E2F32,
  0xFF35A853, 0xFF4E8A4C, 0xFF2B6B4F,
  0xFFF2C230, 0xFFD9A83C, 0xFFC9A227,
  0xFF2E7FD9, 0xFF3E5E78, 0xFF1F4E79,
  0xFFE8821E, 0xFFB06A2E, 0xFFC07A35,
  0xFFF06292, 0xFF64B5F6, 0xFF81C784,
  0xFF6B4A2F, 0xFF4A3220, 0xFF2B2B30,
];

/// Custom theme creator (Pro): pick the six face colors, preview live,
/// save as "My Creation".
class CustomThemeScreen extends StatefulWidget {
  final CubeAudio audio;
  final CubeSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  int _editing = 0;

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
        title: const Text('My Creation',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset colors',
            onPressed: () {
              widget.audio.click();
              widget.settings.resetCustomFaces();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (_, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _preview(theme),
              const SizedBox(height: 16),
              _facePicker(theme),
              const SizedBox(height: 16),
              _paletteGrid(theme),
              const SizedBox(height: 16),
              _useButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(CubeThemeDef theme) {
    final faces = widget.settings.customFaces;
    return PanelCard(
      theme: theme,
      child: Column(
        children: [
          Text('LIVE PREVIEW',
              style: TextStyle(
                  color: theme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2)),
          const SizedBox(height: 10),
          // Flat net preview of the six faces.
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int f = 0; f < 6; f++)
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Color(faces[f]),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: f == _editing
                            ? theme.accent
                            : Colors.black.withValues(alpha: 0.25),
                        width: f == _editing ? 3 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _faceLetters[f],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                                color: Colors.black54,
                                offset: Offset(1, 1))
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _facePicker(CubeThemeDef theme) {
    return PanelCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('EDITING FACE',
              style: TextStyle(
                  color: theme.inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int f = 0; f < 6; f++)
                GestureDetector(
                  onTap: () {
                    widget.audio.select();
                    setState(() => _editing = f);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: f == _editing
                          ? theme.accent
                          : theme.table.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _faceNames[f],
                      style: TextStyle(
                        color:
                            f == _editing ? Colors.white : theme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paletteGrid(CubeThemeDef theme) {
    return PanelCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PICK A COLOR',
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
              for (final argb in _palette)
                GestureDetector(
                  onTap: () {
                    widget.audio.select();
                    widget.settings.setCustomFace(_editing, argb);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(argb),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.settings.customFaces[_editing] ==
                                argb
                            ? theme.accent
                            : Colors.black.withValues(alpha: 0.2),
                        width: widget.settings.customFaces[_editing] ==
                                argb
                            ? 4
                            : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: 0.25),
                          offset: const Offset(0, 3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _useButton(CubeThemeDef theme) {
    final active = widget.settings.themeId == 'custom';
    return Column(
      children: [
        CubeIconButton(
          icon: active ? Icons.check_rounded : Icons.brush_rounded,
          size: 68,
          background: theme.accent,
          tooltip: active ? 'Active' : 'Use my creation',
          onTap: active
              ? null
              : () {
                  widget.audio.win();
                  widget.settings.setTheme('custom');
                  Navigator.of(context).pop();
                },
        ),
        IconLabel(active ? 'ACTIVE' : 'USE MY CREATION',
            color: theme.panel.withValues(alpha: 0.85)),
      ],
    );
  }
}
