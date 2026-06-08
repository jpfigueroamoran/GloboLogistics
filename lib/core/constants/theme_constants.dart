import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Paleta Cromática Globo Logistics ───────────────────────────────────────
// Inspirada en la sobriedad ejecutiva de el-globo.mx:
// negros profundos, blancos limpios, gris acero y azul ejecutivo.

abstract final class GloboColors {
  // Fondos
  static const Color backgroundPrimary = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF4F5F7);
  static const Color backgroundTertiary = Color(0xFFEAECEF);

  // Superficies / Cards
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF8F9FB);
  static const Color surfaceDark = Color(0xFF0F1923);

  // Marca principal: Azul Ejecutivo
  static const Color primary = Color(0xFF0B2545);
  static const Color primaryLight = Color(0xFF1B3F6E);
  static const Color primaryAccent = Color(0xFF1565C0);

  // Acento: Azul eléctrico / tecnológico
  static const Color accent = Color(0xFF0D47A1);
  static const Color accentBright = Color(0xFF1976D2);
  static const Color accentGlow = Color(0xFF42A5F5);

  // Neutros / Gris Acero
  static const Color steelGray = Color(0xFF5C6B7A);
  static const Color steelGrayLight = Color(0xFF8F9EB0);
  static const Color steelGrayExtraLight = Color(0xFFCDD4DC);
  static const Color divider = Color(0xFFE2E6EA);

  // Texto
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF4A5568);
  static const Color textTertiary = Color(0xFF8F9EB0);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkSecondary = Color(0xFFB0C4D8);

  // Semánticos
  static const Color success = Color(0xFF1B5E20);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successAccent = Color(0xFF2E7D32);

  static const Color warning = Color(0xFFE65100);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color warningAccent = Color(0xFFF57C00);

  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorAccent = Color(0xFFD32F2F);

  static const Color info = Color(0xFF01579B);
  static const Color infoLight = Color(0xFFE1F5FE);

  // Estados de unidad
  static const Color estadoOffline = Color(0xFF607D8B);
  static const Color estadoCarga = Color(0xFFF57C00);
  static const Color estadoTransito = Color(0xFF1565C0);
  static const Color estadoDescarga = Color(0xFF2E7D32);

  // SOS / Pánico
  static const Color sosPrimary = Color(0xFFB71C1C);
  static const Color sosSecondary = Color(0xFFD32F2F);
  static const Color sosPulse = Color(0xFFEF5350);
}

// ─── Tipografía ──────────────────────────────────────────────────────────────

abstract final class GloboTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: GloboColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: GloboColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: GloboColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: GloboColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: GloboColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: GloboColors.textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: GloboColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: GloboColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: GloboColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    color: GloboColors.textTertiary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: GloboColors.textTertiary,
    height: 1.4,
  );

  static const TextStyle monoData = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: GloboColors.textPrimary,
  );
}

// ─── Dimensiones y Espaciado ─────────────────────────────────────────────────

abstract final class GloboSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

abstract final class GloboRadius {
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(md));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(sm));
  static const BorderRadius chipRadius =
      BorderRadius.all(Radius.circular(xs));
}

abstract final class GloboElevation {
  static const double none = 0.0;
  static const double low = 1.0;
  static const double medium = 4.0;
  static const double high = 8.0;
}

// ─── ThemeData Principal ──────────────────────────────────────────────────────

final class GloboTheme {
  GloboTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: GloboColors.primary,
        brightness: Brightness.light,
        primary: GloboColors.primary,
        onPrimary: GloboColors.textOnDark,
        primaryContainer: GloboColors.infoLight,
        secondary: GloboColors.accentBright,
        onSecondary: GloboColors.textOnDark,
        surface: GloboColors.surface,
        onSurface: GloboColors.textPrimary,
        error: GloboColors.error,
        onError: GloboColors.textOnDark,
        outline: GloboColors.divider,
        outlineVariant: GloboColors.steelGrayExtraLight,
        surfaceContainerHighest: GloboColors.backgroundSecondary,
      ),
      scaffoldBackgroundColor: GloboColors.backgroundSecondary,
      textTheme: GoogleFonts.interTextTheme(_buildTextTheme(base.textTheme)),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: GloboColors.surface,
        foregroundColor: GloboColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: GloboColors.divider,
        titleTextStyle: GloboTypography.titleLarge,
        iconTheme: IconThemeData(color: GloboColors.textPrimary, size: 22),
        centerTitle: false,
        toolbarHeight: 60,
      ),

      // Card
      cardTheme: CardThemeData(
        color: GloboColors.surface,
        elevation: GloboElevation.low,
        shadowColor: Color(0x1A0B2545),
        shape: RoundedRectangleBorder(
          borderRadius: GloboRadius.cardRadius,
          side: BorderSide(color: GloboColors.divider, width: 0.5),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GloboColors.primary,
          foregroundColor: GloboColors.textOnDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
          textStyle: GloboTypography.labelLarge,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
              horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GloboColors.primary,
          side: const BorderSide(color: GloboColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
          textStyle: GloboTypography.labelLarge,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(
              horizontal: GloboSpacing.lg, vertical: GloboSpacing.md),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: GloboColors.accentBright,
          textStyle: GloboTypography.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GloboColors.backgroundSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GloboSpacing.md,
          vertical: GloboSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: GloboRadius.buttonRadius,
          borderSide: const BorderSide(color: GloboColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: GloboRadius.buttonRadius,
          borderSide: const BorderSide(color: GloboColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: GloboRadius.buttonRadius,
          borderSide:
              const BorderSide(color: GloboColors.primaryAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: GloboRadius.buttonRadius,
          borderSide: const BorderSide(color: GloboColors.error),
        ),
        labelStyle: GloboTypography.bodyMedium,
        hintStyle: GloboTypography.bodyMedium
            .copyWith(color: GloboColors.textTertiary),
        errorStyle: GloboTypography.caption.copyWith(color: GloboColors.error),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: GloboColors.backgroundSecondary,
        selectedColor: GloboColors.primary,
        labelStyle: GloboTypography.labelSmall,
        padding: const EdgeInsets.symmetric(
            horizontal: GloboSpacing.sm, vertical: GloboSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: GloboRadius.chipRadius),
        side: const BorderSide(color: GloboColors.divider),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: GloboColors.divider,
        thickness: 0.5,
        space: 0,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: GloboSpacing.md, vertical: 4),
        titleTextStyle: GloboTypography.titleMedium,
        subtitleTextStyle: GloboTypography.bodyMedium,
        minVerticalPadding: 10,
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GloboColors.surface,
        selectedItemColor: GloboColors.primary,
        unselectedItemColor: GloboColors.steelGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GloboTypography.labelSmall,
        unselectedLabelStyle: GloboTypography.labelSmall,
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GloboColors.primary,
        contentTextStyle: GloboTypography.bodyMedium
            .copyWith(color: GloboColors.textOnDark),
        shape: RoundedRectangleBorder(borderRadius: GloboRadius.buttonRadius),
        behavior: SnackBarBehavior.floating,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GloboColors.primary,
        foregroundColor: GloboColors.textOnDark,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: GloboColors.surface,
        elevation: GloboElevation.high,
        shape: RoundedRectangleBorder(borderRadius: GloboRadius.cardRadius),
        titleTextStyle: GloboTypography.headlineMedium,
        contentTextStyle: GloboTypography.bodyMedium,
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: GloboColors.primary,
        brightness: Brightness.dark,
        primary: GloboColors.accentGlow,
        onPrimary: GloboColors.textPrimary,
        surface: const Color(0xFF0F1923),
        onSurface: GloboColors.textOnDark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0A1320),
      textTheme: GoogleFonts.interTextTheme(_buildDarkTextTheme(base.textTheme)),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: GloboTypography.displayLarge,
      displayMedium: GloboTypography.displayMedium,
      headlineLarge: GloboTypography.headlineLarge,
      headlineMedium: GloboTypography.headlineMedium,
      titleLarge: GloboTypography.titleLarge,
      titleMedium: GloboTypography.titleMedium,
      bodyLarge: GloboTypography.bodyLarge,
      bodyMedium: GloboTypography.bodyMedium,
      labelLarge: GloboTypography.labelLarge,
      labelSmall: GloboTypography.labelSmall,
    );
  }

  static TextTheme _buildDarkTextTheme(TextTheme base) {
    return _buildTextTheme(base).apply(
      bodyColor: GloboColors.textOnDarkSecondary,
      displayColor: GloboColors.textOnDark,
    );
  }
}
