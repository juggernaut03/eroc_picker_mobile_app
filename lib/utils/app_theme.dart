import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color accent = Color(0xFF60A5FA);
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFF0FDF4);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color statusPending = Color(0xFF64748B);
  static const Color statusAssigned = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFFD97706);
  static const Color statusCompleted = Color(0xFF16A34A);
  static const Color statusRejected = Color(0xFFDC2626);
  static const Color statusReassigned = Color(0xFF7C3AED);

  static Color statusColor(String status) {
    switch (status) {
      case 'pending': return statusPending;
      case 'assigned': return statusAssigned;
      case 'in_progress': return statusInProgress;
      case 'completed': return statusCompleted;
      case 'rejected': return statusRejected;
      case 'reassigned': return statusReassigned;
      case 'ready_for_delivery': return const Color(0xFF0891B2);
      case 'out_for_delivery': return const Color(0xFFEA580C);
      case 'delivered': return statusCompleted;
      case 'failed': return statusRejected;
      case 'cancelled': return const Color(0xFF64748B);
      default: return statusPending;
    }
  }

  static Color statusBgColor(String status) {
    switch (status) {
      case 'pending': return const Color(0xFFF1F5F9);
      case 'assigned': return primaryLight;
      case 'in_progress': return warningLight;
      case 'completed': return successLight;
      case 'rejected': return errorLight;
      case 'reassigned': return const Color(0xFFF5F3FF);
      case 'ready_for_delivery': return const Color(0xFFECFEFF);
      case 'out_for_delivery': return const Color(0xFFFFF7ED);
      case 'delivered': return successLight;
      case 'failed': return errorLight;
      case 'cancelled': return const Color(0xFFF1F5F9);
      default: return const Color(0xFFF1F5F9);
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'assigned': return 'Assigned';
      case 'in_progress': return 'In Progress';
      case 'completed': return 'Completed';
      case 'rejected': return 'Rejected';
      case 'reassigned': return 'Reassigned';
      case 'ready_for_delivery': return 'Ready for delivery';
      case 'out_for_delivery': return 'Out for delivery';
      case 'delivered': return 'Delivered';
      case 'failed': return 'Failed';
      case 'cancelled': return 'Cancelled';
      default: return status.replaceAll('_', ' ');
    }
  }

  static Color itemStatusColor(String status) {
    switch (status) {
      case 'picked': return success;
      case 'not_available': return error;
      case 'expired': return warning;
      case 'damaged': return const Color(0xFFBE185D);
      case 'pending':
      default: return textMuted;
    }
  }

  static String itemStatusLabel(String status) {
    switch (status) {
      case 'picked': return 'Picked';
      case 'not_available': return 'N/A';
      case 'expired': return 'Expired';
      case 'damaged': return 'Damaged';
      case 'pending':
      default: return 'Pending';
    }
  }

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: surface,
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
        dividerTheme: const DividerThemeData(color: border, space: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primary,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: primary,
          unselectedLabelColor: textSecondary,
          indicatorColor: primary,
          dividerColor: border,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
}
