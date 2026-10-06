import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vert / Jaune / Rouge du Bénin, adoucis pour l'écran.
class AppColors {
  static const green = Color(0xFF1B7547); // validation, bouton principal
  static const yellow = Color(0xFFE5A93B); // alertes, statut neutre
  static const red = Color(0xFFB8432F); // erreurs, sortie
  static const lightBg = Color(0xFFF8F9FA);
  static const darkBg = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: b,
      primary: AppColors.green,
      secondary: AppColors.yellow,
      error: AppColors.red,
      surface: isDark ? AppColors.darkSurface : Colors.white,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: b).textTheme),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    );
  }
}

/// Fine bande tricolore en haut de l'écran.
class FlagStripe extends StatelessWidget {
  const FlagStripe({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 4,
        child: Row(children: [
          Expanded(child: ColoredBox(color: AppColors.green)),
          Expanded(child: ColoredBox(color: AppColors.yellow)),
          Expanded(child: ColoredBox(color: AppColors.red)),
        ]),
      );
}
