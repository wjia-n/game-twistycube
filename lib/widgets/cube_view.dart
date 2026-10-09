import 'dart:math';
import 'package:flutter/material.dart';
import '../engine/cube_engine.dart';
import '../theme/cube_themes.dart';

/// Animated turn snapshot consumed by the painter.
class TurnAnim {
  final int face;
  final bool clockwise;
  final double t; // 0..1
  const TurnAnim({required this.face, required this.clockwise, required this.t});
}

/// Interactive pseudo-3D twisty cube.
///
/// - Drag anywhere to orbit the view.
/// - Tap a sticker to select its face (highlighted with an accent ring).
/// - Face turns animate: the turning layer physically rotates about the
///   face axis, driven by the engine's [CubeEngine.animFace]/[animClockwise].
/// - Stickers are drawn as physical tiles (bevel shading from a fixed
///   light) in the active theme's face colors and sticker style.
class CubeView extends StatefulWidget {
  final CubeEngine engine;
  final CubeThemeDef theme;
  final int stickerStyle;
  final int selectedFace;
  final ValueChanged<int> onSelectFace;

  const CubeView({
    super.key,
    required this.engine,
    required this.theme,
    required this.stickerStyle,
    required this.selectedFace,
    required this.onSelectFace,
  });

  @override
  State<CubeView> createState() => _CubeViewState();
}

class _CubeViewState extends State<CubeView>
    with SingleTickerProviderStateMixin {
  double _yaw = -0.6;
  double _pitch = 0.5;
  late final AnimationController _turnAnim;
  TurnAnim? _anim;
  int _lastStickerKey = 0;
  _CubePainter? _painter;

  @override
  void initState() {
    super.initState();
    _turnAnim = AnimationController(vsync: this);
    _turnAnim.addStatusListener(_onAnimStatus);
    widget.engine.addListener(_onEngine);
  }

  @override
  void didUpdateWidget(CubeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      oldWidget.engine.removeListener(_onEngine);
      widget.engine.addListener(_onEngine);
    }
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngine);
    _turnAnim.dispose();
    super.dispose();
  }

  void _onAnimStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final e = widget.engine;
      // Settle the move only for player turns; the scramble engine
      // advances itself. The watchdog is the backstop if this is missed.
      if (e.phase == CubePhase.turning) e.finishTurn();
      if (mounted) setState(() => _anim = null);
    }
  }

  void _onEngine() {
    if (!mounted) return;
    final e = widget.engine;
    final key = identityHashCode(e.stickers);
    if ((e.phase == CubePhase.turning || e.phase == CubePhase.scrambling) &&
        key != _lastStickerKey) {
      _lastStickerKey = key;
      // A new move arrived mid-animation: restart from the new snapshot.
      _anim = TurnAnim(face: e.animFace, clockwise: e.animClockwise, t: 0);
      _turnAnim.duration = e.phase == CubePhase.scrambling
          ? const Duration(milliseconds: 110)
          : const Duration(milliseconds: 250);
      _turnAnim.forward(from: 0);
      setState(() {});
    } else if (e.phase == CubePhase.ready || e.phase == CubePhase.solved) {
      if (_anim != null) setState(() => _anim = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        setState(() {
          _yaw += d.delta.dx * 0.008;
          _pitch = (_pitch + d.delta.dy * 0.008).clamp(-1.1, 1.1);
        });
      },
      onTapUp: (d) {
        final face = _painter?.faceAt(d.localPosition);
        if (face != null && face != widget.selectedFace) {
          widget.onSelectFace(face);
        }
      },
      child: AnimatedBuilder(
        animation: _turnAnim,
        builder: (context, _) {
          final anim = _anim == null
              ? null
              : TurnAnim(
                  face: _anim!.face,
                  clockwise: _anim!.clockwise,
                  t: _turnAnim.value,
                );
          _painter = _CubePainter(
            stickers: widget.engine.stickers,
            size: widget.engine.size,
            faces: widget.theme.faces,
            stickerStyle: widget.stickerStyle,
            selectedFace: widget.selectedFace,
            accent: widget.theme.accent,
            panel: widget.theme.panel,
            yaw: _yaw,
            pitch: _pitch,
            anim: anim,
          );
          return CustomPaint(painter: _painter, child: const SizedBox.expand());
        },
      ),
    );
  }
}

// Face geometry: normal, u (column dir), v (row dir). Matches the engine's
// stickerCoords() layout exactly.
const _normals = [
  [0.0, 1.0, 0.0], // U
  [1.0, 0.0, 0.0], // R
  [0.0, 0.0, 1.0], // F
  [0.0, -1.0, 0.0], // D
  [0.0, 0.0, -1.0], // B
  [-1.0, 0.0, 0.0], // L
];
const _uDirs = [
  [1.0, 0.0, 0.0],
  [0.0, 0.0, -1.0],
  [1.0, 0.0, 0.0],
  [1.0, 0.0, 0.0],
  [-1.0, 0.0, 0.0],
  [0.0, 0.0, 1.0],
];
const _vDirs = [
  [0.0, 0.0, 1.0],
  [0.0, -1.0, 0.0],
  [0.0, -1.0, 0.0],
  [0.0, 0.0, -1.0],
  [0.0, -1.0, 0.0],
  [0.0, -1.0, 0.0],
];
const _faceAxis = [1, 0, 2, 1, 2, 0];
const _faceSign = [1, 1, 1, -1, -1, -1];

class _DrawItem {
  final double depth;
  final void Function(Canvas, double) draw; // scale-aware draw
  final List<Offset>? hitQuad; // projected sticker corners (unscaled space)
  final int face;
  _DrawItem(
      {required this.depth,
      required this.draw,
      this.hitQuad,
      required this.face});
}

class _CubePainter extends CustomPainter {
  final List<int> stickers;
  final int size;
  final List<Color> faces;
  final int stickerStyle;
  final int selectedFace;
  final Color accent;
  final Color panel;
  final double yaw;
  final double pitch;
  final TurnAnim? anim;

  // Hit-test registry, front-to-back.
  final List<_DrawItem> _items = [];

  _CubePainter({
    required this.stickers,
    required this.size,
    required this.faces,
    required this.stickerStyle,
    required this.selectedFace,
    required this.accent,
    required this.panel,
    required this.yaw,
    required this.pitch,
    required this.anim,
  });

  int? faceAt(Offset pos) {
    for (final it in _items) {
      final q = it.hitQuad;
      if (q != null && _pointInPoly(pos, q)) return it.face;
    }
    return null;
  }

  bool _pointInPoly(Offset p, List<Offset> poly) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  List<double> _rotY(List<double> p, double a) {
    final c = cos(a), s = sin(a);
    return [p[0] * c + p[2] * s, p[1], -p[0] * s + p[2] * c];
  }

  List<double> _rotX(List<double> p, double a) {
    final c = cos(a), s = sin(a);
    return [p[0], p[1] * c - p[2] * s, p[1] * s + p[2] * c];
  }

  List<double> _view(List<double> p) => _rotX(_rotY(p, yaw), pitch);

  @override
  void paint(Canvas canvas, Size sizePx) {
    _items.clear();
    final n = size;
    final h = (n - 1) / 2.0;
    final plane = n / 2.0;
    const gap = 0.07;
    final tileHalf = 0.5 - gap;

    // Turn-animation rotation for the active layer. The engine has already
    // applied the move, so we draw the layer rotated BACK by (1-t) of the
    // turn angle: clockwise's inverse = +90 deg about the signed face axis.
    double animAngle = 0; // radians about +axis
    int animAx = 0;
    if (anim != null) {
      final s = _faceSign[anim!.face];
      final dir = anim!.clockwise ? 1.0 : -1.0;
      animAx = _faceAxis[anim!.face];
      animAngle = dir * (1.0 - anim!.t) * (pi / 2) * s;
    }

    List<double> turnRot(List<double> p, bool onLayer) {
      if (!onLayer || anim == null) return p;
      final a = (animAx + 1) % 3, b = (animAx + 2) % 3;
      final c = cos(animAngle), s = sin(animAngle);
      final q = [p[0], p[1], p[2]];
      final pa = q[a], pb = q[b];
      q[a] = pa * c - pb * s;
      q[b] = pa * s + pb * c;
      return q;
    }

    bool layerOf(List<int> dc) {
      if (anim == null) return false;
      return _faceSign[anim!.face] * dc[animAx] >= n - 1;
    }

    for (int f = 0; f < 6; f++) {
      final N = _normals[f], U = _uDirs[f], V = _vDirs[f];
      final fc = _mul(N, plane);
      // Face plate (dark body showing through the gaps).
      final plateCorners = [
        _add(fc, _add(_mul(U, plane), _mul(V, plane))),
        _add(fc, _add(_mul(U, -plane), _mul(V, plane))),
        _add(fc, _add(_mul(U, -plane), _mul(V, -plane))),
        _add(fc, _add(_mul(U, plane), _mul(V, -plane))),
      ];
      final plateDepth = _view(fc)[2];
      _items.add(_DrawItem(
        depth: plateDepth - 0.01,
        face: f,
        draw: (canvas, k) {
          final pts = [
            for (final c3 in plateCorners) _proj(_view(c3), sizePx, k)
          ];
          final path = Path()..addPolygon(pts, true);
          canvas.drawPath(
              path, Paint()..color = const Color(0xFF2A2118));
        },
      ));

      for (int r = 0; r < n; r++) {
        for (int c = 0; c < n; c++) {
          final idx = f * n * n + r * n + c;
          final dc = stickerCoords(idx, n);
          final onLayer = layerOf(dc);
          final center = _add(
              fc, _add(_mul(U, c - h), _mul(V, r - h)));
          final corners = [
            _add(center, _add(_mul(U, tileHalf), _mul(V, tileHalf))),
            _add(center, _add(_mul(U, -tileHalf), _mul(V, tileHalf))),
            _add(center, _add(_mul(U, -tileHalf), _mul(V, -tileHalf))),
            _add(center, _add(_mul(U, tileHalf), _mul(V, -tileHalf))),
          ];
          final rc = corners.map((p) => turnRot(p, onLayer)).toList();
          final vc = rc.map(_view).toList();
          final depth = vc.map((p) => p[2]).reduce((a, b) => a + b) / 4;
          // Shading: fixed light in view space gives physical material feel.
          var nv = _view(turnRot(N, onLayer));
          final nl = (nv[0] * 0.35 + nv[1] * 0.75 + nv[2] * 0.55);
          final bright =
              (0.68 + 0.32 * nl.clamp(0.0, 1.0)).clamp(0.55, 1.0).toDouble();
          final base = faces[stickers[idx]];
          final shaded = _shade(base, bright);
          final isSel = f == selectedFace;
          _items.add(_DrawItem(
            depth: depth,
            face: f,
            draw: (canvas, k) {
              final pts = [
                for (final p in vc) _proj(p, sizePx, k),
              ];
              _drawSticker(canvas, pts, shaded, base, isSel);
            },
            hitQuad: null, // filled below after projection scale is known
          ));
          // Store unscaled projected points for hit-testing later.
          _items.last = _DrawItem(
            depth: depth,
            face: f,
            draw: _items.last.draw,
            hitQuad: vc
                .map((p) => Offset(p[0], -p[1]))
                .toList(), // view-space, pre-scale
          );
        }
      }
    }

    _items.sort((a, b) => a.depth.compareTo(b.depth));
    final k = min(sizePx.width, sizePx.height) / (n * 2.35);
    for (final it in _items) {
      it.draw(canvas, k);
    }
    // Convert hit quads to screen space now that k is known.
    final cx = sizePx.width / 2, cy = sizePx.height / 2;
    for (int i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.hitQuad != null) {
        _items[i] = _DrawItem(
          depth: it.depth,
          face: it.face,
          draw: it.draw,
          hitQuad: [
            for (final p in it.hitQuad!) Offset(cx + p.dx * k, cy + p.dy * k)
          ],
        );
      }
    }
    // Front-to-back for hit-testing.
    _items.sort((a, b) => b.depth.compareTo(a.depth));
  }

  Offset _proj(List<double> p, Size s, double k) =>
      Offset(s.width / 2 + p[0] * k, s.height / 2 - p[1] * k);

  void _drawSticker(Canvas canvas, List<Offset> pts, Color fill, Color base,
      bool selected) {
    final path = _stickerPath(pts);
    // Drop shadow under the tile for physical depth.
    canvas.drawPath(
      path.shift(const Offset(0, 2.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawPath(path, Paint()..color = fill);
    // Top-light bevel: lighter inner edge.
    final bevel = Path()..addPolygon([pts[0], pts[1]], false);
    canvas.drawPath(
        bevel,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    // Outline.
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke);
    if (selected) {
      canvas.drawPath(
          path,
          Paint()
            ..color = accent
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke);
    }
  }

  Path _stickerPath(List<Offset> pts) {
    switch (stickerStyle) {
      case 3: // Circle
        return _circlePath(pts, 0.46);
      case 4: // Diamond
        return Path()
          ..addPolygon(
              [_mid(pts[0], pts[1]), _mid(pts[1], pts[2]),
               _mid(pts[2], pts[3]), _mid(pts[3], pts[0])],
              true);
      case 5: // Hexagon
        return _polyPath(pts, 6, 0.46);
      case 6: // Gem
        final p = Path()
          ..addPolygon(
              [_mid(pts[0], pts[1]), _mid(pts[1], pts[2]),
               _mid(pts[2], pts[3]), _mid(pts[3], pts[0])],
              true);
        return p;
      case 7: // Dot
        return _circlePath(pts, 0.22);
      case 1: // Classic Tile
        return Path()..addPolygon(pts, true);
      case 2: // Cushion
        return _roundedPoly(pts, 0.30);
      default: // Rounded
        return _roundedPoly(pts, 0.18);
    }
  }

  Path _circlePath(List<Offset> pts, double frac) {
    final c = pts.reduce((a, b) => a + b) / 4;
    double r = 0;
    for (final p in pts) {
      r = max(r, (p - c).distance);
    }
    return Path()
      ..addOval(Rect.fromCircle(center: c, radius: r * frac * 2 / 1.42));
  }

  Path _polyPath(List<Offset> pts, int sides, double frac) {
    final c = pts.reduce((a, b) => a + b) / 4;
    double r = 0;
    for (final p in pts) {
      r = max(r, (p - c).distance);
    }
    r *= frac * 2 / 1.42;
    final v = [
      for (int i = 0; i < sides; i++)
        Offset(c.dx + r * cos(2 * pi * i / sides - pi / 2),
            c.dy + r * sin(2 * pi * i / sides - pi / 2))
    ];
    return Path()..addPolygon(v, true);
  }

  Path _roundedPoly(List<Offset> pts, double frac) {
    // Rounded quad: walk edges, cutting corners by frac of edge length.
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final prev = pts[(i + 3) % 4];
      final cur = pts[i];
      final next = pts[(i + 1) % 4];
      final e1 = (cur - prev).distance * frac;
      final e2 = (next - cur).distance * frac;
      final p1 = cur + (prev - cur) * (e1 / (cur - prev).distance);
      final p2 = cur + (next - cur) * (e2 / (next - cur).distance);
      if (i == 0) {
        path.moveTo(p1.dx, p1.dy);
      } else {
        path.lineTo(p1.dx, p1.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  Offset _mid(Offset a, Offset b) => (a + b) / 2;

  Color _shade(Color c, double b) {
    return Color.fromARGB(
      c.alpha,
      (c.red * b).round().clamp(0, 255),
      (c.green * b).round().clamp(0, 255),
      (c.blue * b).round().clamp(0, 255),
    );
  }

  List<double> _add(List<double> a, List<double> b) =>
      [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
  List<double> _mul(List<double> a, double s) => [a[0] * s, a[1] * s, a[2] * s];

  @override
  bool shouldRepaint(covariant _CubePainter old) => true;
}
