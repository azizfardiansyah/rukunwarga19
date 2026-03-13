import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class AppPalette {
  const AppPalette._();

  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF10B981);

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);

  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color surfaceSubtle = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  static const Color darkBackground = Color(0xFF09111F);
  static const Color darkSurface = Color(0xFF101A2B);
  static const Color darkSurfaceRaised = Color(0xFF172235);
  static const Color darkSurfaceTint = Color(0xFF21314A);
  static const Color darkBorder = Color(0xFF24354E);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);

  static const Color categoryData = Color(0xFF3B82F6);
  static const Color categoryLayanan = Color(0xFFEF4444);
  static const Color categoryInfo = Color(0xFF8B5CF6);
  static const Color categoryReport = Color(0xFF10B981);

  static const Color iconBgDataWarga = Color(0xFFDBEAFE);
  static const Color iconBgKartuKeluarga = Color(0xFFFFEDD5);
  static const Color iconBgDokumen = Color(0xFFE0F2FE);
  static const Color iconBgSurat = Color(0xFFFFE4E6);
  static const Color iconBgIuran = Color(0xFFFEF3C7);
  static const Color iconBgKegiatan = Color(0xFFEDE9FE);
  static const Color iconBgOrganisasi = Color(0xFFE2E8F0);
  static const Color iconBgPengumuman = Color(0xFFFCE7F3);
  static const Color iconBgLaporan = Color(0xFFDCFCE7);

  static const Color iconDataWarga = Color(0xFF2563EB);
  static const Color iconKartuKeluarga = Color(0xFFEA580C);
  static const Color iconDokumen = Color(0xFF0EA5E9);
  static const Color iconSurat = Color(0xFFFB7185);
  static const Color iconIuran = Color(0xFFD97706);
  static const Color iconKegiatan = Color(0xFF8B5CF6);
  static const Color iconOrganisasi = Color(0xFF64748B);
  static const Color iconPengumuman = Color(0xFFE11D48);
  static const Color iconLaporan = Color(0xFF16A34A);

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'verified':
      case 'completed':
      case 'approved':
      case 'approved_rt':
      case 'approved_rw':
      case 'paid':
      case 'lunas':
        return success;
      case 'warning':
      case 'pending':
      case 'draft':
      case 'submitted':
      case 'submitted_verification':
      case 'need_revision':
      case 'perlu_revisi':
      case 'revisi':
      case 'menunggu':
      case 'unpaid':
      case 'forwarded_to_rw':
        return warning;
      case 'error':
      case 'rejected':
      case 'rejected_payment':
      case 'ditolak':
      case 'tertunggak':
      case 'failed':
      case 'overdue':
        return error;
      case 'info':
      case 'closed':
      default:
        return info;
    }
  }

  static Color categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'data':
      case 'data_penduduk':
      case 'warga':
        return categoryData;
      case 'layanan':
      case 'surat':
      case 'dokumen':
      case 'iuran':
        return categoryLayanan;
      case 'info':
      case 'chat':
      case 'pengumuman':
      case 'organisasi':
        return categoryInfo;
      case 'report':
      case 'laporan':
      case 'finance':
      case 'keuangan':
      default:
        return categoryReport;
    }
  }
}

class AppColors {
  const AppColors._();

  static const Color primary = AppPalette.primary;
  static const Color primaryLight = AppPalette.primaryLight;
  static const Color primaryDark = AppPalette.primaryDark;
  static const Color secondary = AppPalette.secondary;
  static const Color accent = AppPalette.accent;
  static const Color statusSuccess = AppPalette.success;
  static const Color statusWarning = AppPalette.warning;
  static const Color statusError = AppPalette.error;
  static const Color statusInfo = AppPalette.info;
  static const Color categoryData = AppPalette.categoryData;
  static const Color categoryLayanan = AppPalette.categoryLayanan;
  static const Color categoryInfo = AppPalette.categoryInfo;
  static const Color categoryReport = AppPalette.categoryReport;
  static const Color iconBgDataWarga = AppPalette.iconBgDataWarga;
  static const Color iconBgKartuKeluarga = AppPalette.iconBgKartuKeluarga;
  static const Color iconBgDokumen = AppPalette.iconBgDokumen;
  static const Color iconBgSurat = AppPalette.iconBgSurat;
  static const Color iconBgIuran = AppPalette.iconBgIuran;
  static const Color iconBgKegiatan = AppPalette.iconBgKegiatan;
  static const Color iconBgOrganisasi = AppPalette.iconBgOrganisasi;
  static const Color iconBgPengumuman = AppPalette.iconBgPengumuman;
  static const Color iconBgLaporan = AppPalette.iconBgLaporan;
  static const Color iconDataWarga = AppPalette.iconDataWarga;
  static const Color iconKartuKeluarga = AppPalette.iconKartuKeluarga;
  static const Color iconDokumen = AppPalette.iconDokumen;
  static const Color iconSurat = AppPalette.iconSurat;
  static const Color iconIuran = AppPalette.iconIuran;
  static const Color iconKegiatan = AppPalette.iconKegiatan;
  static const Color iconOrganisasi = AppPalette.iconOrganisasi;
  static const Color iconPengumuman = AppPalette.iconPengumuman;
  static const Color iconLaporan = AppPalette.iconLaporan;
  static const Color textPrimary = AppPalette.textPrimary;
  static const Color textSecondary = AppPalette.textSecondary;
  static const Color textTertiary = AppPalette.textTertiary;
  static const Color bgWhite = AppPalette.surface;
  static const Color bgLight = AppPalette.surfaceMuted;
  static const Color bgLighter = AppPalette.surfaceSubtle;
  static const Color borderLight = AppPalette.border;
  static const Color borderMedium = AppPalette.borderStrong;
  static const Color darkBackground = AppPalette.darkBackground;
  static const Color darkSurface = AppPalette.darkSurface;
  static const Color darkSurfaceRaised = AppPalette.darkSurfaceRaised;
  static const Color darkSurfaceTint = AppPalette.darkSurfaceTint;
  static const Color darkBorder = AppPalette.darkBorder;
  static const Color darkTextPrimary = AppPalette.darkTextPrimary;
  static const Color darkTextSecondary = AppPalette.darkTextSecondary;
  static const Color darkTextTertiary = AppPalette.darkTextTertiary;

  static Color statusColor(String status) => AppPalette.statusColor(status);
  static Color categoryColor(String category) =>
      AppPalette.categoryColor(category);

  static Color moduleIconBackground(String label) {
    switch (label.toLowerCase()) {
      case 'data warga':
      case 'lengkapi warga':
        return iconBgDataWarga;
      case 'kartu keluarga':
      case 'lengkapi kk':
        return iconBgKartuKeluarga;
      case 'dokumen':
        return iconBgDokumen;
      case 'surat pengantar':
        return iconBgSurat;
      case 'iuran':
      case 'keuangan':
        return iconBgIuran;
      case 'organisasi':
        return iconBgOrganisasi;
      case 'pengumuman':
      case 'chat':
        return iconBgPengumuman;
      case 'laporan':
        return iconBgLaporan;
      default:
        return bgLight;
    }
  }

  static Color moduleIconColor(String label) {
    switch (label.toLowerCase()) {
      case 'data warga':
      case 'lengkapi warga':
        return iconDataWarga;
      case 'kartu keluarga':
      case 'lengkapi kk':
        return iconKartuKeluarga;
      case 'dokumen':
        return iconDokumen;
      case 'surat pengantar':
        return iconSurat;
      case 'iuran':
        return iconIuran;
      case 'keuangan':
        return primary;
      case 'organisasi':
        return iconOrganisasi;
      case 'pengumuman':
        return iconPengumuman;
      case 'laporan':
        return iconLaporan;
      case 'chat':
        return secondary;
      default:
        return primary;
    }
  }
}

class AppTypography {
  const AppTypography._();

  static const String fontFamily = 'Plus Jakarta Sans';

  static const TextStyle heading1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.35,
    letterSpacing: 0.15,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: 0.2,
    color: AppColors.textTertiary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.15,
    color: Colors.white,
  );

  static const TextStyle metricValue = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -0.8,
    color: AppColors.textPrimary,
  );

  static const TextStyle metricLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static const TextStyle menuLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle menuHelper = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textTertiary,
  );
}

class AppTheme {
  AppTheme._();

  static const Color primaryColor = AppColors.primary;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color primaryDark = AppColors.primaryDark;
  static const Color secondaryColor = AppColors.secondary;
  static const Color accentColor = AppColors.accent;
  static const Color errorColor = AppColors.statusError;
  static const Color successColor = AppColors.statusSuccess;
  static const Color warningColor = AppColors.statusWarning;
  static const Color infoColor = AppColors.statusInfo;
  static const Color backgroundColor = AppColors.bgLight;
  static const Color surfaceColor = AppColors.bgWhite;
  static const Color bgWhite = AppColors.bgWhite;
  static const Color bgLight = AppColors.bgLight;
  static const Color bgLighter = AppColors.bgLighter;
  static const Color darkBackgroundColor = AppColors.darkBackground;
  static const Color darkSurfaceColor = AppColors.darkSurface;
  static const Color darkSurfaceRaised = AppColors.darkSurfaceRaised;
  static const Color darkBorderColor = AppColors.darkBorder;
  static const Color darkTextPrimary = AppColors.darkTextPrimary;
  static const Color darkTextSecondary = AppColors.darkTextSecondary;
  static const Color darkTextTertiary = AppColors.darkTextTertiary;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textTertiary = AppColors.textTertiary;
  static const Color dividerColor = AppColors.borderLight;
  static const Color lightGray = AppColors.borderLight;
  static const Color extraLightGray = AppColors.bgLighter;
  static const Color darkGray = Color(0xFF1E293B);
  static const Color statusError = AppColors.statusError;
  static const Color statusWarning = AppColors.statusWarning;
  static const Color statusSuccess = AppColors.statusSuccess;
  static const Color statusInfo = AppColors.statusInfo;

  static const Color toneRose = AppColors.iconDataWarga;
  static const Color toneAmber = AppColors.iconKartuKeluarga;
  static const Color toneSienna = AppColors.iconDokumen;
  static const Color toneTerracotta = AppColors.primary;
  static const Color toneCrimson = AppColors.iconSurat;
  static const Color toneCharcoal = AppColors.iconOrganisasi;
  static const Color toneSlate = AppColors.textSecondary;
  static const Color tonePink = AppColors.iconPengumuman;
  static const Color toneGold = AppColors.iconIuran;

  static const TextStyle heading1 = AppTypography.heading1;
  static const TextStyle heading2 = AppTypography.heading2;
  static const TextStyle heading3 = AppTypography.heading3;
  static const TextStyle heading4 = AppTypography.heading4;
  static const TextStyle bodyLarge = AppTypography.bodyLarge;
  static const TextStyle bodyMedium = AppTypography.body;
  static const TextStyle bodySmall = AppTypography.bodySmall;
  static const TextStyle caption = AppTypography.labelSmall;
  static const TextStyle buttonText = AppTypography.button;
  static const TextStyle labelMedium = AppTypography.label;

  static const double radiusSmall = 10.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 18.0;
  static const double radiusXLarge = 24.0;
  static const double radiusXXLarge = 30.0;
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  static const double elevationSmall = 1.0;
  static const double elevationMedium = 4.0;
  static const double elevationLarge = 10.0;
  static const Duration fastDuration = Duration(milliseconds: 140);
  static const Duration mediumDuration = Duration(milliseconds: 220);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF0B1220), Color(0xFF132238), Color(0xFF1A2F4D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF4F7FB), Color(0xFFF8FAFC), Color(0xFFEFF4FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: secondaryColor,
          onSecondary: Colors.white,
          tertiary: accentColor,
          surface: surfaceColor,
          onSurface: textPrimary,
          error: errorColor,
          onError: Colors.white,
          outline: dividerColor,
          outlineVariant: lightGray,
          surfaceContainerHighest: AppColors.bgLighter,
          surfaceContainerHigh: AppColors.bgLight,
          surfaceContainer: AppColors.bgWhite,
        );

    return _buildTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldColor: backgroundColor,
      cardColor: surfaceColor,
      inputFillColor: AppColors.bgWhite,
      borderColor: dividerColor,
      labelColor: textSecondary,
      hintColor: textTertiary,
      foregroundPrimary: textPrimary,
      foregroundSecondary: textSecondary,
      foregroundTertiary: textTertiary,
      navIndicator: primaryColor.withValues(alpha: 0.12),
      chipBackground: AppColors.bgLighter,
      snackColor: const Color(0xFF0F172A),
      popupColor: surfaceColor,
      dialogColor: surfaceColor,
      bottomSheetColor: surfaceColor,
    );
  }

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primaryLight,
          onPrimary: Colors.white,
          secondary: secondaryColor,
          onSecondary: Colors.white,
          tertiary: accentColor,
          surface: darkSurfaceColor,
          onSurface: darkTextPrimary,
          error: errorColor,
          onError: Colors.white,
          outline: darkBorderColor,
          outlineVariant: darkSurfaceRaised,
          surfaceContainerHighest: darkSurfaceRaised,
          surfaceContainerHigh: AppColors.darkSurfaceTint,
          surfaceContainer: darkSurfaceColor,
        );

    return _buildTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldColor: darkBackgroundColor,
      cardColor: darkSurfaceColor,
      inputFillColor: darkSurfaceRaised,
      borderColor: darkBorderColor,
      labelColor: darkTextSecondary,
      hintColor: darkTextTertiary,
      foregroundPrimary: darkTextPrimary,
      foregroundSecondary: darkTextSecondary,
      foregroundTertiary: darkTextTertiary,
      navIndicator: primaryLight.withValues(alpha: 0.18),
      chipBackground: darkSurfaceRaised,
      snackColor: darkSurfaceRaised,
      popupColor: darkSurfaceRaised,
      dialogColor: darkSurfaceColor,
      bottomSheetColor: darkSurfaceColor,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required Color scaffoldColor,
    required Color cardColor,
    required Color inputFillColor,
    required Color borderColor,
    required Color labelColor,
    required Color hintColor,
    required Color foregroundPrimary,
    required Color foregroundSecondary,
    required Color foregroundTertiary,
    required Color navIndicator,
    required Color chipBackground,
    required Color snackColor,
    required Color popupColor,
    required Color dialogColor,
    required Color bottomSheetColor,
  }) {
    final textTheme = _textTheme(
      primary: foregroundPrimary,
      secondary: foregroundSecondary,
      tertiary: foregroundTertiary,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldColor,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: cardColor.withValues(alpha: 0.90),
        foregroundColor: foregroundPrimary,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingSmall,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: borderColor),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: AppTypography.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.22)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: AppTypography.button.copyWith(color: colorScheme.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: labelColor),
        hintStyle: textTheme.bodyMedium?.copyWith(color: hintColor),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor.withValues(alpha: 0.96),
        elevation: 0,
        height: 70,
        indicatorColor: navIndicator,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.labelSmall.copyWith(
            color: selected ? colorScheme.primary : foregroundTertiary,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : foregroundTertiary,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBackground,
        selectedColor: colorScheme.primary.withValues(alpha: 0.14),
        secondarySelectedColor: colorScheme.primary.withValues(alpha: 0.18),
        disabledColor: chipBackground,
        labelStyle: AppTypography.bodySmall.copyWith(
          color: foregroundPrimary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: AppTypography.bodySmall.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 0.8,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackColor,
        contentTextStyle: AppTypography.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bottomSheetColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: foregroundTertiary,
        dividerColor: Colors.transparent,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTypography.label.copyWith(fontSize: 13),
        unselectedLabelStyle: AppTypography.label.copyWith(
          fontSize: 13,
          color: foregroundTertiary,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: popupColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: borderColor),
        ),
        textStyle: AppTypography.body,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primary.withValues(alpha: 0.12),
        circularTrackColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: snackColor,
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        textStyle: AppTypography.bodySmall.copyWith(color: Colors.white),
      ),
      dividerColor: borderColor,
      listTileTheme: ListTileThemeData(
        iconColor: foregroundSecondary,
        textColor: foregroundPrimary,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: colorScheme.primary,
      ),
    );
  }

  static TextTheme _textTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
  }) {
    return TextTheme(
      headlineLarge: heading1.copyWith(color: primary),
      headlineMedium: heading2.copyWith(color: primary),
      titleLarge: heading3.copyWith(color: primary),
      titleMedium: AppTypography.heading4.copyWith(color: primary),
      bodyLarge: bodyLarge.copyWith(color: primary),
      bodyMedium: bodyMedium.copyWith(color: primary),
      bodySmall: bodySmall.copyWith(color: secondary),
      labelLarge: AppTypography.button.copyWith(color: Colors.white),
      labelMedium: labelMedium.copyWith(color: secondary),
      labelSmall: caption.copyWith(color: tertiary),
    );
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static LinearGradient surfaceGradientFor(BuildContext context) {
    if (isDark(context)) {
      return const LinearGradient(
        colors: [Color(0xFF09111F), Color(0xFF0D1728), Color(0xFF132238)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
    return surfaceGradient;
  }

  static LinearGradient headerGradientFor(BuildContext context) {
    if (isDark(context)) {
      return const LinearGradient(
        colors: [Color(0xFF08101D), Color(0xFF102039), Color(0xFF183153)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return headerGradient;
  }

  static Color pageBackgroundFor(BuildContext context) =>
      isDark(context) ? darkBackgroundColor : backgroundColor;

  static Color cardColorFor(BuildContext context) =>
      isDark(context) ? darkSurfaceColor : surfaceColor;

  static Color cardBorderColorFor(BuildContext context) =>
      isDark(context) ? darkBorderColor : dividerColor;

  static Color primaryTextFor(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color secondaryTextFor(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color tertiaryTextFor(BuildContext context) =>
      isDark(context) ? darkTextTertiary : textTertiary;

  static BoxDecoration cardDecorationFor(
    BuildContext context, {
    double borderRadius = radiusLarge,
    Color? color,
    bool hasBorder = true,
  }) {
    final shadowPrimary = isDark(context)
        ? Colors.black.withValues(alpha: 0.24)
        : const Color(0xFF0F172A).withValues(alpha: 0.05);
    final shadowSoft = isDark(context)
        ? Colors.black.withValues(alpha: 0.18)
        : primaryColor.withValues(alpha: 0.04);
    return BoxDecoration(
      color: color ?? cardColorFor(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: cardBorderColorFor(context)) : null,
      boxShadow: [
        BoxShadow(
          color: shadowPrimary,
          blurRadius: isDark(context) ? 18 : 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: shadowSoft,
          blurRadius: isDark(context) ? 8 : 16,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration accentCardDecorationFor(
    BuildContext context, {
    required Color accentColor,
    double borderRadius = radiusLarge,
  }) {
    return BoxDecoration(
      color: cardColorFor(context),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: isDark(context) ? 0.16 : 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration glassDecoration({
    double opacity = 0.84,
    double borderRadius = radiusLarge,
    double blur = 10.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.18),
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
          blurRadius: blur * 1.6,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration cardDecoration({
    double borderRadius = radiusLarge,
    Color? color,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: color ?? surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: dividerColor) : null,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static BoxDecoration accentCardDecoration({
    required Color accentColor,
    double borderRadius = radiusLarge,
  }) {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.10),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  static Widget glassContainer({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double opacity = 0.82,
    double blur = 8.0,
    double borderRadius = radiusLarge,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(paddingMedium),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  static Color statusColor(String status) => AppColors.statusColor(status);

  static Widget statusBadge(String status, {String? label}) {
    final color = statusColor(status);
    final displayLabel = label ?? status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        displayLabel,
        style: caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  static Color roleColor(String role) {
    if (AppConstants.normalizeSystemRole(role) ==
        AppConstants.systemRoleOperator) {
      return primaryColor;
    }
    if (AppConstants.normalizeSystemRole(role) ==
        AppConstants.systemRoleSysadmin) {
      return secondaryColor;
    }
    switch (AppConstants.normalizeRole(role)) {
      case AppConstants.roleSysadmin:
        return secondaryColor;
      case AppConstants.roleAdminRwPro:
        return accentColor;
      case AppConstants.roleAdminRw:
        return primaryDark;
      case AppConstants.roleAdminRt:
        return primaryColor;
      case AppConstants.roleWarga:
      default:
        return toneSlate;
    }
  }

  static Widget iconContainer({
    required IconData icon,
    required Color color,
    double size = 40,
    double iconSize = 20,
    double borderRadius = 12,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
