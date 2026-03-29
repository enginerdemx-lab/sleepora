import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A14);
  static const card = Color(0xFF1A1025);
  static const cardDark = Color(0xFF120D1E);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFF9D5FF3);
  static const purpleDark = Color(0xFF6D28D9);
  static const purpleCard = Color(0xFF2D1B4E);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFF6B7280);
  static const greyLight = Color(0xFF9CA3AF);
  static const navBar = Color(0xFF111827);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.purple,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.purple,
        secondary: AppColors.green,
        surface: AppColors.card,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.navBar,
        selectedItemColor: AppColors.purple,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
