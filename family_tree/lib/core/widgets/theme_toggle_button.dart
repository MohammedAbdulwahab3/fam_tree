import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/providers/theme_provider.dart';

/// A reusable theme toggle button widget
class ThemeToggleButton extends ConsumerWidget {
  final double size;
  final bool showLabel;
  
  const ThemeToggleButton({
    super.key,
    this.size = 40,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          color: isDark 
              ? AppTheme.surfaceDark.withOpacity(0.8)
              : ElegantColors.warmWhite.withOpacity(0.9),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: isDark 
                ? AppTheme.primaryLight.withOpacity(0.3)
                : ElegantColors.terracotta.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black26 
                  : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                key: ValueKey(isDark),
                size: size * 0.5,
                color: isDark 
                    ? AppTheme.accentGold 
                    : ElegantColors.terracotta,
              ),
            ),
            if (showLabel) ...[
              SizedBox(width: size * 0.15),
              Text(
                isDark ? 'Dark' : 'Light',
                style: TextStyle(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w500,
                  color: isDark 
                      ? AppTheme.textPrimary 
                      : ElegantColors.charcoal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A minimal icon-only theme toggle for app bars
class ThemeToggleIcon extends ConsumerWidget {
  final double size;
  final Color? color;
  
  const ThemeToggleIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          key: ValueKey(isDark),
          size: size,
          color: color ?? (isDark ? AppTheme.accentGold : ElegantColors.charcoal),
        ),
      ),
      tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
    );
  }
}
