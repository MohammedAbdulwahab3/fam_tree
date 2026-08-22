import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';

/// Slowly drifting emerald/teal light used behind the app's entry screens.
///
/// Three large radial washes orbit on a long loop behind a heavy blur, so the
/// motion reads as ambient light rather than something competing for attention.
class AuroraBackground extends StatelessWidget {
  final Animation<double> animation;
  final bool isDark;

  /// Scales every orb's opacity — lower it where content sits on top.
  final double intensity;

  const AuroraBackground({
    super.key,
    required this.animation,
    required this.isDark,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value * 2 * math.pi;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF0B1220),
                      Color(0xFF0F172A),
                      Color(0xFF0C1F2B),
                    ]
                  : const [
                      ElegantColors.warmWhite,
                      ElegantColors.cream,
                      Color(0xFFEDF5F1),
                    ],
            ),
          ),
          child: Stack(
            children: [
              _orb(
                color: AppTheme.primaryLight,
                alignment: Alignment(
                  -0.75 + 0.16 * math.cos(t),
                  -0.65 + 0.14 * math.sin(t),
                ),
                size: 420,
                opacity: (isDark ? 0.30 : 0.20) * intensity,
              ),
              _orb(
                color: AppTheme.accentCyan,
                alignment: Alignment(
                  0.85 + 0.14 * math.cos(t + math.pi / 2),
                  -0.35 + 0.18 * math.sin(t + math.pi / 2),
                ),
                size: 360,
                opacity: (isDark ? 0.24 : 0.16) * intensity,
              ),
              _orb(
                color: AppTheme.accentTeal,
                alignment: Alignment(
                  0.25 + 0.20 * math.cos(t + math.pi),
                  0.85 + 0.12 * math.sin(t + math.pi),
                ),
                size: 460,
                opacity: (isDark ? 0.22 : 0.15) * intensity,
              ),
              // Melts the orbs into the background so no hard edge shows.
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: const SizedBox.expand(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _orb({
    required Color color,
    required Alignment alignment,
    required double size,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
