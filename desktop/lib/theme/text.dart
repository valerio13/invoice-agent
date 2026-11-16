// Text styles of the design: Montserrat, with wide tracking on the uppercase labels.
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// False in widget tests, which run without network and so without Google Fonts.
bool useGoogleFonts = true;

TextStyle _montserrat(double size, FontWeight weight, Color color, [double tracking = 0]) {
  final style = TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: size * tracking,
    height: 1.2,
  );
  return useGoogleFonts ? GoogleFonts.montserrat(textStyle: style) : style;
}

abstract final class AppText {
  /// Uppercase label, as in pills, stat tiles and chart axes. Write the text in uppercase.
  static TextStyle label({Color color = AppColors.text, double size = AppSizes.fsMicro}) =>
      _montserrat(size, FontWeight.w700, color, 0.09);

  /// Uppercase label on ink, a little lighter.
  static TextStyle panelLabel({Color color = AppColors.onInk, double size = AppSizes.fsMicro}) =>
      _montserrat(size, FontWeight.w600, color, 0.08);

  /// Large light figure: amounts, counts, dates.
  static TextStyle figure({Color color = AppColors.textSoft, double size = AppSizes.fsFigure}) =>
      _montserrat(size, FontWeight.w400, color);

  static TextStyle title() => _montserrat(AppSizes.fsTitle, FontWeight.w700, AppColors.text, 0.12);

  static TextStyle nav(Color color) => _montserrat(AppSizes.fsNav, FontWeight.w500, color, 0.06);

  static TextStyle brand() => _montserrat(AppSizes.fsBrand, FontWeight.w700, AppColors.onInk, 0.04);

  static TextStyle body({Color color = AppColors.text, double size = AppSizes.fsBody}) =>
      _montserrat(size, FontWeight.w400, color).copyWith(height: 1.5);

  static TextStyle button(Color color, double size) =>
      _montserrat(size, FontWeight.w700, color, 0.1);
}
