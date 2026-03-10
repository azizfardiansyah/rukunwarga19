import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  // === COLORS ===
  static const Color primaryColor = Color(0xFF1F7A63);
  static const Color primaryLight = Color(0xFF4E9D86);
  static const Color primaryDark = Color(0xFF175B4B);
  static const Color secondaryColor = Color(0xFF90A89D);
  static const Color accentColor = Color(0xFFD5A24A);
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFE6A700);
  static const Color backgroundColor = Color(0xFFF5F7F6);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color dividerColor = Color(0xFFE5E7EB);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF175B4B), Color(0xFF1F7A63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF164F42), Color(0xFF1F7A63), Color(0xFF5EA68D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === TEXT STYLES ===
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.15,
    letterSpacing: -0.3,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.25,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.35,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // === BORDER RADIUS ===
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // === PADDING ===
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // === ELEVATION ===
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationLarge = 8.0;

  // === LIGHT THEME ===
  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surfaceColor,
          surfaceContainerHighest: const Color(0xFFF0F3F1),
          error: errorColor,
          onPrimary: Colors.white,
          onSurface: textPrimary,
          onSecondary: textPrimary,
          outline: dividerColor,
        );

    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
      fontFamily: 'Roboto',
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
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceColor.withValues(alpha: 0.78),
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: dividerColor),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: buttonText,
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: dividerColor),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FBFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingMedium,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor, width: 1.6),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: bodyMedium,
        hintStyle: bodyMedium.copyWith(color: textSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor.withValues(alpha: 0.9),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppTheme.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? primaryColor
                : textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        indicatorColor: primaryColor.withValues(alpha: 0.12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F3F1),
        selectedColor: primaryLight.withValues(alpha: 0.2),
        labelStyle: bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXLarge),
        ),
      ),
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 0.5),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF24322E),
        contentTextStyle: bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor.withValues(alpha: 0.84),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      dividerColor: dividerColor,
    );
  }

  // === DARK THEME ===
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
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: elevationSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
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
            vertical: paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: paddingMedium,
          vertical: paddingMedium,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // === GLASSMORPHISM DECORATION ===
  static BoxDecoration glassDecoration({
    double opacity = 0.72,
    double borderRadius = radiusLarge,
    double blur = 12.0,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.45),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: blur,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration cardDecoration({
    double borderRadius = radiusLarge,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // === HELPER: Glassmorphism Container Widget ===
  static Widget glassContainer({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double opacity = 0.76,
    double blur = 10.0,
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
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  // === HELPER: Status Color ===
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return textSecondary;
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

  // === HELPER: Role Badge Color ===
  static Color roleColor(String role) {
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
}
