import 'package:flutter/material.dart';
import 'colors.dart';

class FerriTheme {
  FerriTheme._();

  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: FerriColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: FerriColors.primary,
          surface: FerriColors.bgCard,
          error: FerriColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: FerriColors.bgCard,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: FerriColors.bgCard,
          elevation: 0,
        ),
      );
}
