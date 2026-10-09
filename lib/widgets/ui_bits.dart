import 'package:flutter/material.dart';
import '../theme/cube_themes.dart';

/// Modern icon-based controls: small circular icon buttons with animated
/// press feedback. No big dated text buttons.
class CubeIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? foreground;
  final String? tooltip;

  const CubeIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 56,
    this.background,
    this.foreground,
    this.tooltip,
  });

  @override
  State<CubeIconButton> createState() => _CubeIconButtonState();
}

class _CubeIconButtonState extends State<CubeIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final btn = GestureDetector(
      onTapDown: (_) {
        if (disabled) return;
        setState(() => _down = true);
        _press.forward();
      },
      onTapUp: (_) {
        setState(() => _down = false);
        _press.reverse();
      },
      onTapCancel: () {
        setState(() => _down = false);
        _press.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, _) {
          final s = 1.0 - 0.12 * _press.value;
          return Transform.scale(
            scale: s,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.background ??
                    Theme.of(context).colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _down ? 0.15 : 0.35),
                    offset: Offset(0, _down ? 2 : 5),
                    blurRadius: _down ? 6 : 12,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                size: widget.size * 0.48,
                color: widget.foreground ?? Colors.white,
              ),
            ),
          );
        },
      ),
    );
    if (disabled) return Opacity(opacity: 0.35, child: btn);
    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: btn);
    }
    return btn;
  }
}

/// Small label chip used under icon buttons.
class IconLabel extends StatelessWidget {
  final String text;
  final Color color;
  const IconLabel(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Section card with the theme's panel styling.
class PanelCard extends StatelessWidget {
  final Widget child;
  final CubeThemeDef theme;
  final EdgeInsets padding;
  const PanelCard({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.panel,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Lock badge shown on Pro-only options.
class ProLock extends StatelessWidget {
  final double size;
  const ProLock({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF8A6D3B),
      ),
      child: Icon(Icons.lock, size: size, color: Colors.white),
    );
  }
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
