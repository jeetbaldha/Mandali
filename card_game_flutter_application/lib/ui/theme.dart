import 'package:flutter/material.dart';

import '../core/theme/brand.dart';

ThemeData mandaliTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: Brand.ink,
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontFamily: 'Lora',
      fontSize: 25,
      color: Brand.ivory,
      height: 1.25,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Lora',
      fontSize: 30,
      color: Brand.ivory,
    ),
    bodyMedium: TextStyle(fontSize: 15, height: 1.4),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xffeaca8e),
    onPrimary: Color(0xff172b29),
    secondary: Color(0xff75c8ac),
    surface: Color(0xff132c2e),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xff0d2024),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(110, 52),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
      shape: BeveledRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(100, 50),
      side: const BorderSide(color: Color(0xff4c6a60)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  chipTheme: ChipThemeData(
    side: const BorderSide(color: Color(0xff3b5550)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
