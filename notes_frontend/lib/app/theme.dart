import 'package:flutter/material.dart';

ThemeData buildNotesTheme() {
  const purple = Color(0xFF5E35B1);
  const teal = Color(0xFF11B7B0);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: purple,
    brightness: Brightness.light,
  ).copyWith(
    primary: purple,
    secondary: teal,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSurface: const Color(0xFF111827),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF9FAFB),
    appBarTheme: const AppBarTheme(
      backgroundColor: purple,
      foregroundColor: Colors.white,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: teal,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE6E6E6), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFE6E6E6), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
      ),
    ),
  );
}
