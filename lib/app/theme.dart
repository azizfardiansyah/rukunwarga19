import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════
  // COLORS — warm, bold, signature palette
  // No green, blue, or purple. Coral / Charcoal / Amber identity.
  // ═══════════════════════════════════════════════════════════════════
  static const Color primaryColor = Color(0xFFE8453C);     // bold coral-red
  static const Color primaryLight = Color(0xFFFF6F61);     // soft coral
  static const Color primaryDark = Color(0xFFC02E25);      // deep crimson
  static const Color secondaryColor = Color(0xFF3C3C3C);   // charcoal
  static const Color accentColor = Color(0xFFE8983C);      // warm amber
  static const Color errorColor = Color(0xFFD32F2F);       // classic red
  static const Color successColor = Color(0xFF2E7D32);     // dark forest (muted)
  static const Color warningColor = Color(0xFFF9A825);     // golden yellow
  static const Color infoColor = Color(0xFFE8453C);        // same as primary — no blue
  static const Color backgroundColor = Color(0xFFF5F2EE);  // warm off-white
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);      // near-black
  static const Color textSecondary = Color(0xFF6B6B6B);    // warm gray
  static const Color textTertiary = Color(0xFFA3A3A3);     // light warm gray
  static const Color dividerColor = Color(0xFFE5E0DA);     // warm divider

  // Semantic tones for menus (distinct, warm-family, NO blue/green/purple)
  static const Color toneRose = Color(0xFFE8453C);
  static const Color toneAmber = Color(0xFFE8983C);
  static const Color toneSienna = Color(0xFFB45309);
  static const Color toneTerracotta = Color(0xFFD2691E);
  static const Color toneCrimson = Color(0xFFC02E25);
  static const Color toneCharcoal = Color(0xFF3C3C3C);
  static const Color toneSlate = Color(0xFF6B6B6B);
  static const Color tonePink = Color(0xFFE84575);
  static const Color toneGold = Color(0xFFD4A017);

  // Gradient colors — warm, dramatic
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFC02E25), Color(0xFFE8453C), Color(0xFFFF6F61)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF2D2222), Color(0xFF3C2A2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFFF5F2EE), Color(0xFFFFFFFF), Color(0xFFF0ECE6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFE8453C), Color(0xFFE8983C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════════
  // TEXT STYLES — bolder, more character
  // ═══════════════════════════════════════════════════════════════════
  static const TextStyle heading1 = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w900,
    color: textPrimary,
    height: 1.1,
    letterSpacing: -0.8,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.25,
    letterSpacing: -0.2,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.45,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    height: 1.35,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: 0.3,
  );

  // ═══════════════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════════
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  static const double radiusXXLarge = 28.0;

  // ═══════════════════════════════════════════════════════════════════
  // PADDING
  // ═══════════════════════════════════════════════════════════════════
  static const double paddingXSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // ═══════════════════════════════════════════════════════════════════
  // ELEVATION
  // ═══════════════════════════════════════════════════════════════════
  static const double elevationSmall = 1.0;
  static const double elevationMedium = 3.0;
  static const double elevationLarge = 6.0;

  // ═══════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surfaceColor,
          surfaceContainerHighest: const Color(0xFFF0ECE6),
          error: errorColor,
          onPrimary: Colors.white,
          onSurface: textPrimary,
          onSecondary: Colors.white,
          outline: dividerColor,
        );

    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: baseTextTheme.copyWith(
        headlineLarge: heading1,
        headlineMedium: heading2,
        titleLarge: heading3,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelSmall: caption,
        labelMedium: labelMedium,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor.withValues(alpha: 0.92),
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: BorderSide(color: dividerColor.withValues(alpha: 0.6)),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingSmall,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F2EE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: bodyMedium.copyWith(color: textSecondary),
        hintStyle: bodyMedium.copyWith(color: textTertiary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor.withValues(alpha: 0.95),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? primaryColor
                : textTertiary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 11,
          );
        }),
        indicatorColor: primaryColor.withValues(alpha: 0.1),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? primaryColor
                : textTertiary,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0ECE6),
        selectedColor: primaryLight.withValues(alpha: 0.15),
        labelStyle: bodySmall.copyWith(fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1A1A),
        contentTextStyle: bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
        elevation: 8,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXLarge),
          ),
        ),
        elevation: 8,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textTertiary,
        indicatorColor: primaryColor,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      dividerColor: dividerColor,
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        elevation: 4,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryLight,
        secondary: secondaryColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingSmall,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: paddingLarge,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // GLASSMORPHISM DECORATION
  // ═══════════════════════════════════════════════════════════════════
  static BoxDecoration glassDecoration({
    double opacity = 0.78,
    double borderRadius = radiusLarge,
    double blur = 10.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.5),
        width: 0.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: blur,
          offset: const Offset(0, 4),
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
      border: hasBorder
          ? Border.all(color: dividerColor.withValues(alpha: 0.5))
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Signature elevated card with colored top accent stripe
  static BoxDecoration accentCardDecoration({
    required Color accentColor,
    double borderRadius = radiusLarge,
  }) {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: dividerColor.withValues(alpha: 0.4)),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER: Glassmorphism Container Widget
  // ═══════════════════════════════════════════════════════════════════
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER: Status Color
  // ═══════════════════════════════════════════════════════════════════
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return textTertiary;
      case 'submitted':
      case 'forwarded_to_rw':
      case 'approved':
      case 'approved_rt':
      case 'approved_rw':
      case 'lunas':
        return primaryColor;
      case 'completed':
      case 'paid':
      case 'verified':
        return successColor;
      case 'need_revision':
      case 'perlu_revisi':
      case 'revisi':
      case 'submitted_verification':
        return accentColor;
      case 'pending':
      case 'menunggu':
      case 'unpaid':
        return warningColor;
      case 'rejected':
      case 'ditolak':
      case 'tertunggak':
      case 'rejected_payment':
        return errorColor;
      case 'closed':
        return textSecondary;
      default:
        return textSecondary;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER: Semantic status badge
  // ═══════════════════════════════════════════════════════════════════
  static Widget statusBadge(String status, {String? label}) {
    final color = statusColor(status);
    final displayLabel = label ?? status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        displayLabel,
        style: caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER: Role Badge Color
  // ═══════════════════════════════════════════════════════════════════
  static Color roleColor(String role) {
    if (AppConstants.normalizeSystemRole(role) ==
        AppConstants.systemRoleOperator) {
      return primaryColor;
    }
    if (AppConstants.normalizeSystemRole(role) ==
        AppConstants.systemRoleSysadmin) {
      return primaryDark;
    }
    switch (AppConstants.normalizeRole(role)) {
      case AppConstants.roleSysadmin:
        return primaryDark;
      case AppConstants.roleAdminRwPro:
        return accentColor;
      case AppConstants.roleAdminRw:
        return secondaryColor;
      case AppConstants.roleAdminRt:
        return primaryColor;
      case AppConstants.roleWarga:
      default:
        return primaryLight;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER: Icon container (used in stat cards, menu, etc.)
  // ═══════════════════════════════════════════════════════════════════
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
