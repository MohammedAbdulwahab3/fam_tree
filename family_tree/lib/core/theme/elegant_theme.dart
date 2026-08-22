import 'package:flutter/material.dart';

/// Elegant color palette inspired by warm, sophisticated tones
/// Used across the app for consistent styling
class ElegantColors {
  // Background tones
  static const cream = Color(0xFFFAF7F2);
  static const warmWhite = Color(0xFFFFFCF7);
  static const parchment = Color(0xFFF5F0E6);
  
  // Additional for web layouts
  static const offWhite = Color(0xFFFEFCFA);
  
  // Accent colors - Terracotta/Sienna family
  static const terracotta = Color(0xFFCD5C45);
  static const sienna = Color(0xFFA0522D);
  static const rust = Color(0xFFB7472A);
  static const copper = Color(0xFFB87333);
  
  // Complementary tones
  static const sage = Color(0xFF8B9A7D);
  static const dustyRose = Color(0xFFD4A5A5);
  static const warmGray = Color(0xFF8B8178);
  static const charcoal = Color(0xFF3D3833);
  
  // Gold accents
  static const gold = Color(0xFFD4AF37);
  static const champagne = Color(0xFFF7E7CE);
  
  // Soft accent colors
  static const softTeal = Color(0xFF5BA3A3);
  static const softBlue = Color(0xFF6B8CAE);
  static const softPurple = Color(0xFF8B7B9B);
  
  // Family branch colors - distinct colors for each family line
  static const List<Color> branchColors = [
    Color(0xFFCD5C45),  // Terracotta
    Color(0xFF5B8C5A),  // Forest Green
    Color(0xFF6B5B95),  // Purple
    Color(0xFF3498DB),  // Ocean Blue
    Color(0xFFE67E22),  // Orange
    Color(0xFF1ABC9C),  // Teal
    Color(0xFFE74C3C),  // Red
    Color(0xFF9B59B6),  // Violet
    Color(0xFF2ECC71),  // Emerald
    Color(0xFFF39C12),  // Amber
    Color(0xFF16A085),  // Sea Green
    Color(0xFFD35400),  // Pumpkin
  ];
  
  // Gradients
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [terracotta, sienna],
  );
  
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, Color(0xFFE8C252)],
  );
  
  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sage, Color(0xFF9AAD8C)],
  );
}
