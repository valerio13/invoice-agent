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
  final themed = useGoogleFonts
      ? base.copyWith(textTheme: GoogleFonts.montserratTextTheme(base.textTheme))
      : base;
  // The date picker's large headline is made the size of the app's figures.
  final headline = (themed.textTheme.headlineSmall ?? const TextStyle()).copyWith(
    fontSize: AppSizes.fsFigure,
    fontWeight: FontWeight.w400,
    color: AppColors.textSoft,
  );
  return themed.copyWith(
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      headerHeadlineStyle: headline,
      rangePickerHeaderHeadlineStyle: headline,
      rangeSelectionBackgroundColor: AppColors.accentTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.rPanel)),
    ),
  );
}
