import 'package:flutter/material.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/app_colors.dart';

/// The app's mark: a small line-art family tree — one root, a branch bar, and
/// three descendants — inside a softly glowing rounded tile.
class TreeMark extends StatelessWidget {
  /// Whether to draw for a dark ground.
  ///
  /// Defaults to the ambient theme, which is what every ordinary caller wants.
  /// It is only worth passing when the mark sits on a panel that is dark
  /// regardless of the theme, as it does in the landing hero.
  final bool? isDark;

  final double size;

  /// Multiplies the outer glow; used by the landing hero to pulse.
  final double glow;

  const TreeMark({
    super.key,
    required this.size,
    this.isDark,
    this.glow = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final dark = isDark ?? Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryLight.withValues(alpha: dark ? 0.22 : 0.16),
            AppTheme.accentCyan.withValues(alpha: dark ? 0.16 : 0.10),
          ],
        ),
        border: Border.all(
          color: AppTheme.accentTeal.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentTeal.withValues(
                alpha: ((dark ? 0.28 : 0.18) * glow).clamp(0.0, 1.0)),
            blurRadius: 26 * glow,
            spreadRadius: (glow - 1) * 8,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _TreeMarkPainter(
          isDark: dark,
          trunk: context.colors.accent,
          canopy: context.colors.secondary,
        ),
      ),
    );
  }
}

class _TreeMarkPainter extends CustomPainter {
  final bool isDark;
  final Color trunk;
  final Color canopy;

  _TreeMarkPainter({
    required this.isDark,
    required this.trunk,
    required this.canopy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = trunk.withValues(alpha: 0.95)
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final root = Offset(w / 2, h * 0.12);
    final midY = h * 0.5;
    final leaves = [
      Offset(w * 0.12, h * 0.9),
      Offset(w / 2, h * 0.9),
      Offset(w * 0.88, h * 0.9),
    ];

    // Trunk down to the branch bar, then a drop to each child.
    canvas.drawLine(root, Offset(w / 2, midY), line);
    canvas.drawLine(
        Offset(leaves.first.dx, midY), Offset(leaves.last.dx, midY), line);
    for (final leaf in leaves) {
      canvas.drawLine(
          Offset(leaf.dx, midY), Offset(leaf.dx, leaf.dy - h * 0.08), line);
    }

    final dot = Paint()
      ..color = canopy
      ..style = PaintingStyle.fill;
    canvas.drawCircle(root, w * 0.085, dot);
    for (final leaf in leaves) {
      canvas.drawCircle(Offset(leaf.dx, leaf.dy - h * 0.05), w * 0.07, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeMarkPainter old) =>
      old.isDark != isDark || old.trunk != trunk || old.canopy != canopy;
}
