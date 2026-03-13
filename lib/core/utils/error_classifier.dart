import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../app/theme.dart';

/// Tipe-tipe error yang mungkin terjadi
enum ErrorType {
  network,
  auth,
  forbidden,
  notFound,
  validation,
  server,
  timeout,
  unknown,
}

/// Hasil klasifikasi error
class ClassifiedError {
  final ErrorType type;
  final String message;
  final String? detail;

  const ClassifiedError({
    required this.type,
    required this.message,
    this.detail,
  });
}

class ErrorClassifier {
  ErrorClassifier._();

  /// Klasifikasi error menjadi tipe dan pesan yang user-friendly
  static ClassifiedError classify(dynamic error) {
    // PocketBase ClientException
    if (error is ClientException) {
      return _classifyPocketBaseError(error);
    }

    // Network errors
    if (error is SocketException) {
      return const ClassifiedError(
        type: ErrorType.network,
        message: 'Tidak dapat terhubung ke server',
        detail: 'Periksa koneksi internet Anda dan pastikan server berjalan',
      );
    }

    // Timeout
    if (error is HttpException) {
      return const ClassifiedError(
        type: ErrorType.timeout,
        message: 'Koneksi timeout',
        detail: 'Server tidak merespons. Coba lagi nanti',
      );
    }

    // Format exception
    if (error is FormatException) {
      return ClassifiedError(
        type: ErrorType.unknown,
        message: 'Format data tidak valid',
        detail: error.message,
      );
    }

    // Unknown error
    return ClassifiedError(
      type: ErrorType.unknown,
      message: 'Terjadi kesalahan',
      detail: error.toString(),
    );
  }

  /// Klasifikasi error dari PocketBase
  static ClassifiedError _classifyPocketBaseError(ClientException error) {
    final statusCode = error.statusCode;
    final extractedMessage = _extractPocketBaseMessage(error);
    final normalizedMessage = (extractedMessage ?? '').toLowerCase();

    switch (statusCode) {
      case 400:
        return ClassifiedError(
          type: ErrorType.validation,
          message: 'Data tidak valid',
          detail: extractedMessage,
        );
      case 401:
        return const ClassifiedError(
          type: ErrorType.auth,
          message: 'Sesi telah berakhir',
          detail: 'Silakan login kembali',
        );
      case 403:
        return const ClassifiedError(
          type: ErrorType.forbidden,
          message: 'Akses ditolak',
          detail: 'Anda tidak memiliki izin untuk melakukan ini',
        );
      case 404:
        return const ClassifiedError(
          type: ErrorType.notFound,
          message: 'Data tidak ditemukan',
          detail: 'Data yang dicari tidak tersedia',
        );
      case 0:
        return const ClassifiedError(
          type: ErrorType.network,
          message: 'Tidak dapat terhubung ke server',
          detail: 'Periksa koneksi internet dan pastikan PocketBase berjalan',
        );
      default:
        if (statusCode >= 500) {
          if (normalizedMessage.contains('midtrans') &&
              (normalizedMessage.contains('server key') ||
                  normalizedMessage.contains('belum dikonfigurasi'))) {
            return ClassifiedError(
              type: ErrorType.server,
              message: 'Konfigurasi pembayaran belum siap',
              detail: extractedMessage,
            );
          }
          return ClassifiedError(
            type: ErrorType.server,
            message: 'Kesalahan server',
            detail: (extractedMessage ?? '').trim().isNotEmpty
                ? extractedMessage
                : 'Server error ($statusCode). Coba lagi nanti',
          );
        }
        return ClassifiedError(
          type: ErrorType.unknown,
          message: 'Terjadi kesalahan',
          detail: extractedMessage,
        );
    }
  }

  /// Ekstrak pesan error dari PocketBase response
  static String? _extractPocketBaseMessage(ClientException error) {
    try {
      final data = error.response;
      // Cek field-level errors
      if (data.containsKey('data') && data['data'] is Map) {
        final fields = data['data'] as Map;
        final messages = <String>[];
        for (final entry in fields.entries) {
          if (entry.value is Map && entry.value.containsKey('message')) {
            messages.add('${entry.key}: ${entry.value['message']}');
          }
        }
        if (messages.isNotEmpty) return messages.join('\n');
      }
      // Cek top-level message
      if (data.containsKey('message')) {
        return data['message']?.toString();
      }
    } catch (_) {}
    return error.toString();
  }

  /// Tampilkan snackbar error
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final classified = classify(error);
    final snackBar = SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classified.message,
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (classified.detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    classified.detail!,
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      backgroundColor: _colorForType(classified.type),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {},
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Tampilkan snackbar sukses
  static void showSuccessSnackBar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.successColor,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Warna berdasarkan tipe error
  static Color _colorForType(ErrorType type) {
    switch (type) {
      case ErrorType.network:
      case ErrorType.timeout:
        return AppTheme.warningColor;
      case ErrorType.auth:
        return AppTheme.errorColor;
      case ErrorType.forbidden:
        return AppTheme.primaryDark;
      case ErrorType.notFound:
        return AppTheme.secondaryColor;
      case ErrorType.validation:
        return AppTheme.warningColor;
      case ErrorType.server:
        return AppTheme.errorColor;
      case ErrorType.unknown:
        return AppTheme.textPrimary;
    }
  }

  /// Cek apakah error adalah auth error (perlu re-login)
  static bool isAuthError(dynamic error) {
    final classified = classify(error);
    return classified.type == ErrorType.auth;
  }

  /// Cek apakah error adalah network error
  static bool isNetworkError(dynamic error) {
    final classified = classify(error);
    return classified.type == ErrorType.network ||
        classified.type == ErrorType.timeout;
  }
}
