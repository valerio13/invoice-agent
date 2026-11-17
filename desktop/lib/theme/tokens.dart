// Design tokens, the same values as design/tokens.css of the mockups.
import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  // Surfaces
  static const page = Color(0xFFCBDFDE);
  static const pageLight = Color(0xFFDBE9E8);
  static const surface = Color(0xFFE2ECEB);
  static const card = Color(0xFFFFFFFF);
  static const field = Color(0xFFE2EDEC);

  // Ink (dark slate green)
  static const ink = Color(0xFF425C5B);
  static const inkDeep = Color(0xFF3D5653);
  static const inkDot = Color(0xFF6D8685);

  // Text
  static const text = Color(0xFF3E4C4C);
  static const textSoft = Color(0xFF5A6060);
  static const textMuted = Color(0xFF8B9999);
  static const onInk = Color(0xFFFFFFFF);
  static const onInkMuted = Color(0xFFD2E6E5);

  // Accent (gold)
  static const accent = Color(0xFFC99C35);
  static const onAccent = Color(0xFFFFFFFF);
  // Selected ticket: the accent at about 12% on white.
  static const accentTint = Color(0xFFF8F1E3);
}

abstract final class AppSizes {
  static const fsFigure = 22.0;
  static const fsStat = 28.0;
  static const fsBrand = 17.0;
  static const fsNav = 15.0;
  static const fsTitle = 15.0;
  static const fsTotal = 13.0;
  static const fsBody = 11.5;
  static const fsLabel = 11.0;
  static const fsMicro = 9.5;

  static const rWindow = 40.0;
  static const rCard = 40.0;
  static const rPanel = 28.0;
  static const rRow = 20.0;

  static const hField = 54.0;
  static const hGhost = 40.0;
  static const hSmall = 30.0;
  static const hNav = 58.0;
  static const wSidebar = 270.0;
  static const wPanel = 310.0;
}

abstract final class AppShadows {
  static const window = [
    BoxShadow(color: Color(0x80284644), offset: Offset(0, 30), blurRadius: 40, spreadRadius: -26),
  ];
}
