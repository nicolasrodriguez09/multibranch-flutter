import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const midnight = Color(0xFF06152A);
  static const deepNavy = Color(0xFF07162C);
  static const ocean = Color(0xFF0A2A52);
  static const storm = Color(0xFF0B2141);
  static const blue = Color(0xFF2E7BFF);
  static const blueDark = Color(0xFF2251D1);
  static const blueSoft = Color(0xFF79B7FF);
  static const cyan = Color(0xFF97E5FF);
  static const amber = Color(0xFFFFA94D);
  static const amberSoft = Color(0xFFFFD2A1);
  static const mint = Color(0xFF5ED6B3);
  static const danger = Color(0xFFFF7B7B);
  static const textPrimary = Color(0xFFF4F8FF);
  static const textMuted = Color(0xB3D7E5FF);
  static const panel = Color(0x26112642);
  static const panelStrong = Color(0xAA0C1D36);
  static const panelBorder = Color(0x33FFFFFF);
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.blue,
    onPrimary: Colors.white,
    secondary: AppPalette.amber,
    onSecondary: AppPalette.deepNavy,
    error: AppPalette.danger,
    onError: Colors.white,
    surface: AppPalette.deepNavy,
    onSurface: AppPalette.textPrimary,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppPalette.deepNavy,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: AppPalette.textPrimary,
          displayColor: AppPalette.textPrimary,
        )
        .copyWith(
          displaySmall: base.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            height: 1.45,
            color: AppPalette.textPrimary,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            height: 1.45,
            color: AppPalette.textMuted,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppPalette.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppPalette.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppPalette.panelBorder),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppPalette.panel,
      side: const BorderSide(color: AppPalette.panelBorder),
      labelStyle: const TextStyle(
        color: AppPalette.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: AppPalette.textMuted),
      hintStyle: const TextStyle(color: AppPalette.textMuted),
      filled: true,
      fillColor: const Color(0x40142E52),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppPalette.panelBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppPalette.blueSoft, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppPalette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppPalette.danger, width: 1.4),
      ),
    ),
  );
}
