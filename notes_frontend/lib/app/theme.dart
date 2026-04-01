import 'package:flutter/material.dart';

/// Builds the application theme for Notes.
///
/// Tweaks are intentionally focused on matching the provided screenshots:
/// - Purple app bar
/// - Teal FAB
/// - Compact search/input field
/// - Light background with white surfaces
ThemeData buildNotesTheme() {
  const purple = Color(0xFF5E35B1);
  const teal = Color(0xFF11B7B0);
  const background = Color(0xFFF9FAFB);
  const outline = Color(0xFFE6E6E6);
  const text = Color(0xFF111827);
  const muted = Color(0xFF6B7280);

  final colorScheme = ColorScheme.fromSeed(
    seedColor: purple,
    brightness: Brightness.light,
  ).copyWith(
    primary: purple,
    secondary: teal,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSurface: text,
    outline: outline,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    dividerColor: outline,
    visualDensity: VisualDensity.standard,
    textTheme: Typography.material2021().black.copyWith(
          bodyMedium: const TextStyle(color: text, fontSize: 14, height: 1.25),
          bodySmall: const TextStyle(color: muted, fontSize: 12, height: 1.25),
          titleMedium: const TextStyle(
            color: text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: purple,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      minVerticalPadding: 8,
      dense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: muted),
      labelStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: outline, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
      ),
    ),
  );
}
