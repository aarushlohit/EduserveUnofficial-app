import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Emerald Theme - Extreme
  static const Color emeraldPrimary = Color(0xFF10B981); // Emerald 500 - Vivid
  static const Color emeraldDark = Color(0xFF064E3B); // Emerald 900 - Deep
  static const Color emeraldLight = Color(0xFFECFDF5); // Emerald 50 - Very Subtle
  static const Color emeraldAccent = Color(0xFF34D399); // Emerald 400 - Bright

  // Standard
  static const Color primary = emeraldPrimary;
  static const Color backgroundDark = Color(0xFF000000); // True Black for OLED
  static const Color backgroundLight = Color(0xFFFFFFFF); // True White

  static const Color accent = emeraldAccent;
  static const Color textLight = Color(0xFFF8F8FA);
  static const Color cardDark = Color(0xFF121212); // Material Dark Surface
  static const Color danger = Color(0xFFEF4444); // Red 500
  
  // UI Specifics
  static const Color inputBackgroundLight = Color(0xFFFAFAFA);
  static const Color inputBackgroundDark = Color(0xFF262626);
  static const Color dividerLight = Color(0xFFDBDBDB);
  static const Color dividerDark = Color(0xFF363636);
}
