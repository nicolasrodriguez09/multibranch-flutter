import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const midnight = Color(0xFF050506);
  static const deepNavy = Color(0xFF08090C);
  static const ocean = Color(0xFF101116);
  static const storm = Color(0xFF17191F);
  static const blue = Color(0xFFFF2636);
  static const blueDark = Color(0xFFB20D19);
  static const blueSoft = Color(0xFFFF6B73);
  static const cyan = Color(0xFFFF9AA1);
  static const amber = Color(0xFFFF3B47);
  static const amberSoft = Color(0xFFFFC6CA);
  static const mint = Color(0xFFFFDDE0);
  static const danger = Color(0xFFFF4C63);
  static const textPrimary = Color(0xFFF6F7FA);
  static const textMuted = Color(0xB8D6D7DE);
  static const panel = Color(0x331B1D23);
  static const panelStrong = Color(0xD0101116);
  static const panelBorder = Color(0x4DFF2636);
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.blue,
    onPrimary: Colors.white,
    secondary: AppPalette.amber,
    onSecondary: Colors.white,
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
      fillColor: const Color(0x401D1F26),
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
