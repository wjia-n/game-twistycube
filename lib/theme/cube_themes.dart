import 'package:flutter/material.dart';

/// Twisty Cube art direction: pseudo-3D physical materials — toy plastic,
/// wood, marble, candy. No neon, no cyberpunk, no gradients-wash. Each theme
/// defines the six face colors plus the table/panel/accent chrome around the
/// cube.
class CubeThemeDef {
  final String id;
  final String name;
  final List<Color> faces; // U,R,F,D,B,L
  final Color table; // background
  final Color panel; // cards / dialogs
  final Color accent;
  final Color accentDark;
  final Color ink; // primary text
  final Color inkSoft; // secondary text
  final bool isPro;

  const CubeThemeDef({
    required this.id,
    required this.name,
    required this.faces,
    required this.table,
    required this.panel,
    required this.accent,
    required this.accentDark,
    required this.ink,
    required this.inkSoft,
    this.isPro = false,
  });
}

class CubeThemes {
  static const List<CubeThemeDef> all = [
    CubeThemeDef(
      id: 'classic',
      name: 'Classic Toy',
      faces: [
        Color(0xFFF7F3EA), // U white
        Color(0xFFD94040), // R red
        Color(0xFF35A853), // F green
        Color(0xFFF2C230), // D yellow
        Color(0xFF2E7FD9), // B blue
        Color(0xFFE8821E), // L orange
      ],
      table: Color(0xFF6B4A2F),
      panel: Color(0xFFF7F3EA),
      accent: Color(0xFFC98A2B),
      accentDark: Color(0xFF8A5A17),
      ink: Color(0xFF3A2A1A),
      inkSoft: Color(0xFF7A6A55),
    ),
    CubeThemeDef(
      id: 'vintage',
      name: 'Vintage Wood',
      faces: [
        Color(0xFFEFE3CC),
        Color(0xFFA8452F),
        Color(0xFF5E7F43),
        Color(0xFFD9A83C),
        Color(0xFF3E5E78),
        Color(0xFFB06A2E),
      ],
      table: Color(0xFF4A3220),
      panel: Color(0xFFEFE3CC),
      accent: Color(0xFF8A5A2B),
      accentDark: Color(0xFF5E3A17),
      ink: Color(0xFF3A2A1A),
      inkSoft: Color(0xFF7A6A55),
    ),
    CubeThemeDef(
      id: 'candy',
      name: 'Candy Shop',
      faces: [
        Color(0xFFFFF6F8),
        Color(0xFFF06292),
        Color(0xFF81C784),
        Color(0xFFFFD54F),
        Color(0xFF64B5F6),
        Color(0xFFFF8A65),
      ],
      table: Color(0xFF8E5A6B),
      panel: Color(0xFFFFF6F8),
      accent: Color(0xFFE0527E),
      accentDark: Color(0xFFA83A5C),
      ink: Color(0xFF5A3040),
      inkSoft: Color(0xFF9A7A88),
    ),
    CubeThemeDef(
      id: 'ocean',
      name: 'Deep Ocean',
      faces: [
        Color(0xFFEAF6F6),
        Color(0xFFE05A4E),
        Color(0xFF3FA68A),
        Color(0xFFF2C94C),
        Color(0xFF1F6F9E),
        Color(0xFFE8933C),
      ],
      table: Color(0xFF14384A),
      panel: Color(0xFFEAF6F6),
      accent: Color(0xFF2E9E8F),
      accentDark: Color(0xFF1C6B62),
      ink: Color(0xFF16303A),
      inkSoft: Color(0xFF5A7A88),
    ),
    CubeThemeDef(
      id: 'forest',
      name: 'Forest Floor',
      faces: [
        Color(0xFFF1EEDF),
        Color(0xFFB6493B),
        Color(0xFF4E8A4C),
        Color(0xFFD9A83C),
        Color(0xFF3E6B8A),
        Color(0xFFC07A35),
      ],
      table: Color(0xFF2E4423),
      panel: Color(0xFFF1EEDF),
      accent: Color(0xFF6B8F3E),
      accentDark: Color(0xFF47611F),
      ink: Color(0xFF2A3A1E),
      inkSoft: Color(0xFF6B7A5A),
    ),
    CubeThemeDef(
      id: 'desert',
      name: 'Desert Sand',
      faces: [
        Color(0xFFFBF3E2),
        Color(0xFFC65B3F),
        Color(0xFF7A9A4E),
        Color(0xFFE8B93C),
        Color(0xFF4E7A9A),
        Color(0xFFD08030),
      ],
      table: Color(0xFF9A6B3A),
      panel: Color(0xFFFBF3E2),
      accent: Color(0xFFB0762B),
      accentDark: Color(0xFF7A5217),
      ink: Color(0xFF4A3520),
      inkSoft: Color(0xFF8A7560),
    ),
    CubeThemeDef(
      id: 'slate',
      name: 'Slate',
      faces: [
        Color(0xFFEDEFF2),
        Color(0xFFC0392B),
        Color(0xFF27966B),
        Color(0xFFD9A62B),
        Color(0xFF2B6CB0),
        Color(0xFFDD6B20),
      ],
      table: Color(0xFF3A4048),
      panel: Color(0xFFEDEFF2),
      accent: Color(0xFF5A6B7A),
      accentDark: Color(0xFF3A454E),
      ink: Color(0xFF2A3138),
      inkSoft: Color(0xFF6B7683),
    ),
    CubeThemeDef(
      id: 'cherry',
      name: 'Cherry Wood',
      faces: [
        Color(0xFFF8EFE4),
        Color(0xFFB03A2E),
        Color(0xFF3E8A5A),
        Color(0xFFE3A82B),
        Color(0xFF2E5E8A),
        Color(0xFFD0712B),
      ],
      table: Color(0xFF5E2E1E),
      panel: Color(0xFFF8EFE4),
      accent: Color(0xFF9A4A2B),
      accentDark: Color(0xFF6B3017),
      ink: Color(0xFF402418),
      inkSoft: Color(0xFF8A6F5E),
    ),
    // ---- Pro themes ----
    CubeThemeDef(
      id: 'marble',
      name: 'Marble Hall',
      faces: [
        Color(0xFFF5F2EC),
        Color(0xFF9E2B25),
        Color(0xFF2B6B4F),
        Color(0xFFC9A227),
        Color(0xFF1F4E79),
        Color(0xFFB45A1B),
      ],
      table: Color(0xFF2B2B30),
      panel: Color(0xFFF5F2EC),
      accent: Color(0xFF8A6D3B),
      accentDark: Color(0xFF5E4A22),
      ink: Color(0xFF2B2B30),
      inkSoft: Color(0xFF6B6B72),
      isPro: true,
    ),
    CubeThemeDef(
      id: 'ivory',
      name: 'Ivory & Brass',
      faces: [
        Color(0xFFFFFBF0),
        Color(0xFF8E2F32),
        Color(0xFF3F6B4F),
        Color(0xFFD4A017),
        Color(0xFF2F4E6B),
        Color(0xFFB46A28),
      ],
      table: Color(0xFF4A3F2B),
      panel: Color(0xFFFFFBF0),
      accent: Color(0xFFB08D3B),
      accentDark: Color(0xFF7A6222),
      ink: Color(0xFF3A3222),
      inkSoft: Color(0xFF8A7D62),
      isPro: true,
    ),
    CubeThemeDef(
      id: 'sakura',
      name: 'Sakura',
      faces: [
        Color(0xFFFFF5F7),
        Color(0xFFE0607E),
        Color(0xFF7FBF7F),
        Color(0xFFF2CE5F),
        Color(0xFF6B9FD1),
        Color(0xFFF09A5F),
      ],
      table: Color(0xFF6B4A52),
      panel: Color(0xFFFFF5F7),
      accent: Color(0xFFC05A7A),
      accentDark: Color(0xFF8E3A56),
      ink: Color(0xFF52303A),
      inkSoft: Color(0xFF9A7A84),
      isPro: true,
    ),
    CubeThemeDef(
      id: 'midnight',
      name: 'Midnight Study',
      faces: [
        Color(0xFFE8E4D8),
        Color(0xFFA63A3A),
        Color(0xFF3F7A5A),
        Color(0xFFC9A23B),
        Color(0xFF3A5E8A),
        Color(0xFFB46A35),
      ],
      table: Color(0xFF1E2430),
      panel: Color(0xFFE8E4D8),
      accent: Color(0xFF8A7A4A),
      accentDark: Color(0xFF5E5230),
      ink: Color(0xFF232A38),
      inkSoft: Color(0xFF6B7280),
      isPro: true,
    ),
  ];

  static CubeThemeDef byId(String id, {CubeThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => all.any((t) => t.id == id && t.isPro);

  /// Builds the user-designed custom theme from stored face colors.
  static CubeThemeDef customFromColors(List<Color> faces) => CubeThemeDef(
        id: 'custom',
        name: 'My Creation',
        faces: List.of(faces),
        table: const Color(0xFF5A4A3A),
        panel: const Color(0xFFF7F3EA),
        accent: const Color(0xFF8A6D3B),
        accentDark: const Color(0xFF5E4A22),
        ink: const Color(0xFF3A2A1A),
        inkSoft: const Color(0xFF7A6A55),
      );
}

/// Sticker/cube styles — how each little tile is drawn. All physical,
/// toy-like; none of the neon/glow family.
class StickerStyles {
  static const names = [
    'Rounded',
    'Classic Tile',
    'Cushion',
    'Circle',
    'Diamond',
    'Hexagon',
    'Gem',
    'Dot',
  ];
  // Pro-only styles (index >= 5).
  static bool isPro(int i) => i >= 5;
  static int get count => names.length;
}

/// App-level Material theme derived from the active cube theme.
ThemeData cubeAppTheme(CubeThemeDef t) {
  final scheme = ColorScheme.fromSeed(
    seedColor: t.accent,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme.copyWith(
      primary: t.accent,
      secondary: t.accentDark,
      surface: t.panel,
    ),
    scaffoldBackgroundColor: t.table,
    appBarTheme: AppBarTheme(
      backgroundColor: t.table,
      foregroundColor: t.panel,
      elevation: 0,
    ),
    textTheme: Typography.material2021().black.copyWith(
          displayLarge: TextStyle(
              color: t.panel, fontWeight: FontWeight.w800, letterSpacing: 1),
          headlineMedium:
              TextStyle(color: t.ink, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: t.ink),
          bodyMedium: TextStyle(color: t.inkSoft),
        ),
  );
}
