import 'package:flutter/material.dart';

class C {
  const C._();

  static const bg = Color(0xFF080610);
  static const bgDeep = Color(0xFF050309);
  static const plum = Color(0xFF170B2E);
  static const plumLight = Color(0xFF241243);
  static const purple = Color(0xFF8B5CF6);
  static const magenta = Color(0xFFD946EF);
  static const pink = Color(0xFFEC4899);
  static const gold = Color(0xFFFFD765);
  static const goldDeep = Color(0xFFE9A826);
  static const blue = Color(0xFF4F8CFF);
  static const cyan = Color(0xFF22D3EE);
  static const white = Color(0xFFFFFFFF);
  static const text = white;
  static const textDim = Color(0xADFFFFFF);
  static const textFaint = Color(0x6BFFFFFF);
  static const glass = Color(0x12FFFFFF);
  static const glassStrong = Color(0x21FFFFFF);
  static const glassBorder = Color(0x24FFFFFF);
  static const scrim = Color(0x9E050309);
  static const danger = Color(0xFFFB3B66);
  static const success = Color(0xFF34D399);
  static const ink = Color(0xFF201000);
}

class G {
  const G._();

  static const accent = [Color(0xFF8B5CF6), Color(0xFFD946EF), Color(0xFFEC4899)];
  static const gold = [Color(0xFFFFF1BE), Color(0xFFFFD765), Color(0xFFE9A826)];
  static const night = [Color(0xFF170B2E), Color(0xFF080610)];
  static const launch = [Color(0xFF2A1159), Color(0xFF170B2E), Color(0xFF080610)];
  static const panel = [Color(0x1CFFFFFF), Color(0x0AFFFFFF)];
  static const video = [Color(0xFF8B5CF6), Color(0xFFEC4899)];
  static const audio = [Color(0xFF3B82F6), Color(0xFF22D3EE)];
  static const match = [Color(0xFFF59E0B), Color(0xFFEC4899)];
  static const danger = [Color(0xFFFB3B66), Color(0xFFEC4899)];
  static const scrimBottom = [Color(0x00050309), Color(0xEB050309)];
}

class R {
  const R._();

  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
  static const pill = 999.0;
}

/// The thinnest line the screen can draw, as StyleSheet.hairlineWidth.
double hairline(BuildContext context) => 1 / MediaQuery.devicePixelRatioOf(context);

const LinearGradient Function(List<Color>) diagonal = _diagonal;
LinearGradient _diagonal(List<Color> colors) => LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors);

const LinearGradient Function(List<Color>) vertical = _vertical;
LinearGradient _vertical(List<Color> colors) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors);

ThemeData appTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Outfit',
      scaffoldBackgroundColor: C.bg,
      canvasColor: C.bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(primary: C.purple, secondary: C.magenta, surface: C.plum, error: C.danger),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: C.magenta, selectionColor: Color(0x66D946EF), selectionHandleColor: C.magenta),
    );
