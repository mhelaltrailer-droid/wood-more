import 'package:flutter/material.dart';

/// ألوان وثيم Wood & More - متناسقة مع اللوجو
class AppTheme {
  // اللون الأخضر الغامق (من اللوجو)
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color primaryGreenDark = Color(0xFF0D3B0D);
  static const Color primaryGreenLight = Color(0xFF2E7D32);

  // الأسود والرمادي
  static const Color black = Color(0xFF212121);
  static const Color greyDark = Color(0xFF424242);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          secondary: primaryGreenLight,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );
}
