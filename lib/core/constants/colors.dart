import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Royal Blue Palette (Like Reference)
  static const Color royalBlue = Color(0xFF448AFF); // Material Blue A200 - Vibrant
  static const Color royalBlueDark = Color(0xFF2962FF); // Material Blue A700
  static const Color royalBlueLight = Color(0xFF82B1FF); // Material Blue A100
  static const Color royalBackground = Color(0xFFF5F9FF); // Very light blue-white for backgrounds
  
  // Backward compatibility mappings (pointing to new Royal Blue theme)
  static const Color emeraldPrimary = royalBlue;
  static const Color emeraldDark = royalBlueDark;
  static const Color emeraldLight = royalBackground;
  static const Color emeraldAccent = royalBlueLight;

  // Standard Theme Colors
  static const Color primary = royalBlue;
  static const Color secondary = royalBlueLight;
  static const Color backgroundLight = Color(0xFFFFFFFF); // Clean White
  static const Color backgroundDark = Color(0xFF000000); // True Black

  static const Color accent = royalBlueLight;
  static const Color textDark = Color(0xFF1E293B); // Slate 800 for text on white
  static const Color textLight = Color(0xFFFFFFFF); // White text on blue

  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF121212); // Material Dark Surface
  
  static const Color danger = Color(0xFFFF5252); // Keep red for actual danger/errors
  
  // UI Specifics
  static const Color inputBackgroundLight = Color(0xFFF3F4F6);
  static const Color inputBackgroundDark = Color(0xFF262626);
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF363636);
  
  static const Color iconColor = royalBlue;
}
