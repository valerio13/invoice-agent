import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'text.dart';
import 'tokens.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.page,
  );
  if (!useGoogleFonts) return base;
  return base.copyWith(textTheme: GoogleFonts.montserratTextTheme(base.textTheme));
}
