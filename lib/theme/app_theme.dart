import 'package:flutter/material.dart';

class AppTheme {
  static const Color emeraldGreen = Color(0xFF50C878);
  static const Color darkBackground = Color(0xFF1E2124);
  static const Color lighterDarkBackground = Color(0xFF282C34);
  
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: emeraldGreen,
        secondary: emeraldGreen,
        surface: lighterDarkBackground,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        selectedIconTheme: IconThemeData(color: emeraldGreen),
        unselectedIconTheme: IconThemeData(color: Colors.white70),
        selectedLabelTextStyle: TextStyle(color: emeraldGreen, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: Colors.white70),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
