import 'package:flutter/material.dart';
import 'package:focus/theme/cor_destaque.dart';

class AppTheme {
  AppTheme._();

  static const double raio = 16;

  static ThemeData get claro => construir(Brightness.light);
  static ThemeData get escuro => construir(Brightness.dark);

  /// Texto legível em cima da cor: branco nas escuras, quase preto (do mesmo tom) nas claras.
  static Color _textoSobre(Color cor) {
    if (ThemeData.estimateBrightnessForColor(cor) == Brightness.dark) return Colors.white;
    final hsl = HSLColor.fromColor(cor);
    return hsl.withLightness(0.1).withSaturation((hsl.saturation * 0.8).clamp(0, 1)).toColor();
  }

  static ThemeData construir(Brightness brilho, [CorDestaque cor = CorDestaque.padrao]) {
    final escuro = brilho == Brightness.dark;
    final primaria = cor.para(brilho);
    final base = ColorScheme.fromSeed(seedColor: cor.claro, brightness: brilho);
    final esquema = base.copyWith(
      primary: primaria,
      onPrimary: _textoSobre(primaria),
      surface: escuro ? const Color(0xFF0F1113) : const Color(0xFFF7F8F7),
      onSurface: escuro ? const Color(0xFFECEDEC) : const Color(0xFF111312),
      onSurfaceVariant: escuro ? const Color(0xFF9BA19D) : const Color(0xFF6B716D),
      surfaceContainerLowest: escuro ? const Color(0xFF15181A) : Colors.white,
      surfaceContainerLow: escuro ? const Color(0xFF1A1D20) : const Color(0xFFF1F3F1),
      surfaceContainer: escuro ? const Color(0xFF202427) : const Color(0xFFEBEEEB),
      outlineVariant: escuro ? const Color(0xFF2A2F32) : const Color(0xFFE3E6E3),
    );

    final bordaArredondada = RoundedRectangleBorder(borderRadius: BorderRadius.circular(raio));
    final texto = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(bodyColor: esquema.onSurface, displayColor: esquema.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: esquema,
      scaffoldBackgroundColor: esquema.surface,
      splashFactory: InkSparkle.splashFactory,
      textTheme: texto.copyWith(
        headlineMedium: texto.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        headlineSmall: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: esquema.surface,
        foregroundColor: esquema.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        color: esquema.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: bordaArredondada.copyWith(side: BorderSide(color: esquema.outlineVariant)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: esquema.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: esquema.onSurfaceVariant),
        prefixIconColor: esquema.onSurfaceVariant,
        suffixIconColor: esquema.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: esquema.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: esquema.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: texto.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: esquema.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: texto.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: esquema.primary,
        foregroundColor: esquema.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: esquema.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: esquema.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (estados) => IconThemeData(
            color: estados.contains(WidgetState.selected) ? esquema.primary : esquema.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (estados) => TextStyle(
            fontSize: 12,
            fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: estados.contains(WidgetState.selected) ? esquema.onSurface : esquema.onSurfaceVariant,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: esquema.primary.withValues(alpha: 0.14),
          selectedForegroundColor: esquema.onSurface,
          foregroundColor: esquema.onSurfaceVariant,
          side: BorderSide(color: esquema.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: esquema.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: esquema.outlineVariant, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: esquema.primary),
    );
  }
}
