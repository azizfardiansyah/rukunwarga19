import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:flutter/material.dart';

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

    switch (statusCode) {
      case 400:
        return ClassifiedError(
          type: ErrorType.validation,
          message: 'Data tidak valid',
          detail: _extractPocketBaseMessage(error),
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
          return ClassifiedError(
            type: ErrorType.server,
            message: 'Kesalahan server',
            detail: 'Server error ($statusCode). Coba lagi nanti',
          );
        }
        return ClassifiedError(
          type: ErrorType.unknown,
          message: 'Terjadi kesalahan',
          detail: _extractPocketBaseMessage(error),
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classified.message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (classified.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              classified.detail!,
              style: const TextStyle(fontSize: 12),
            ),
          ],
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
      content: Text(message),
      backgroundColor: Colors.green[700],
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
        return Colors.orange[800]!;
      case ErrorType.auth:
        return Colors.red[700]!;
      case ErrorType.forbidden:
        return Colors.red[900]!;
      case ErrorType.notFound:
        return Colors.grey[700]!;
      case ErrorType.validation:
        return Colors.amber[800]!;
      case ErrorType.server:
        return Colors.red[800]!;
      case ErrorType.unknown:
        return Colors.grey[800]!;
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
