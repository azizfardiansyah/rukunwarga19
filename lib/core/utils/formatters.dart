import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  // === TANGGAL ===

  /// Format tanggal: 7 Februari 2026
  static String tanggalLengkap(DateTime date) {
    return DateFormat('d MMMM yyyy', 'id').format(date);
  }

  /// Format tanggal pendek: 07/02/2026
  static String tanggalPendek(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'id').format(date);
  }

  /// Format tanggal form input: 07-02-2026
  static String tanggalInput(DateTime date) {
    return DateFormat('dd-MM-yyyy', 'id').format(date);
  }

  /// Format tanggal & waktu: 7 Feb 2026, 10:30
  static String tanggalWaktu(DateTime date) {
    return DateFormat('d MMM yyyy, HH:mm', 'id').format(date);
  }

  /// Format waktu saja: 10:30
  static String waktu(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Format relatif: Hari ini, Kemarin, 3 hari lalu, dll
  static String tanggalRelatif(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) return 'Baru saja';
        return '${diff.inMinutes} menit lalu';
      }
      return '${diff.inHours} jam lalu';
    } else if (diff.inDays == 1) {
      return 'Kemarin';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} minggu lalu';
    } else {
      return tanggalPendek(date);
    }
  }

  /// Parse string tanggal dari PocketBase (ISO 8601)
  static DateTime? parseTanggal(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    return DateTime.tryParse(dateStr);
  }

  /// Parse tanggal dari input form Indonesia atau ISO.
  static DateTime? parseTanggalInput(String? input) {
    final raw = input?.trim() ?? '';
    if (raw.isEmpty) return null;

    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    final match = RegExp(
      r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$',
    ).firstMatch(raw);
    if (match == null) return null;

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final yearRaw = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || yearRaw == null) return null;

    final year = yearRaw < 100
        ? (yearRaw <= 30 ? 2000 + yearRaw : 1900 + yearRaw)
        : yearRaw;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }

    return parsed;
  }

  // === CURRENCY (RUPIAH) ===

  /// Format Rupiah: Rp 1.500.000
  static String rupiah(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  /// Format Rupiah pendek: Rp 1,5jt
  static String rupiahPendek(num amount) {
    if (amount >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return rupiah(amount);
  }

  /// Parse string rupiah ke number
  static num? parseRupiah(String? value) {
    if (value == null || value.isEmpty) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return num.tryParse(cleaned);
  }

  // === NIK ===

  /// Format NIK: 3201 2345 6789 0001
  static String formatNik(String nik) {
    final cleaned = nik.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 16) return cleaned;
    return '${cleaned.substring(0, 4)} ${cleaned.substring(4, 8)} '
        '${cleaned.substring(8, 12)} ${cleaned.substring(12, 16)}';
  }

  /// Validasi NIK (16 digit)
  static bool isValidNik(String nik) {
    final cleaned = nik.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length == 16;
  }

  // === NO KK ===

  /// Format No KK: 3201 2345 6789 0001
  static String formatNoKk(String noKk) {
    return formatNik(noKk); // Format sama dengan NIK (16 digit)
  }

  /// Validasi No KK (16 digit)
  static bool isValidNoKk(String noKk) {
    return isValidNik(noKk);
  }

  // === NO HP ===

  /// Format No HP: 0812-3456-7890
  static String formatNoHp(String noHp) {
    final cleaned = noHp.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length < 10 || cleaned.length > 13) return cleaned;
    if (cleaned.length <= 12) {
      return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
    }
    return '${cleaned.substring(0, 4)}-${cleaned.substring(4, 8)}-${cleaned.substring(8)}';
  }

  /// Validasi No HP Indonesia (10-13 digit, mulai 08)
  static bool isValidNoHp(String noHp) {
    final cleaned = noHp.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 10 &&
        cleaned.length <= 13 &&
        cleaned.startsWith('08');
  }

  // === NAMA ===

  /// Capitalize setiap kata: budi santoso -> Budi Santoso
  static String capitalizeName(String name) {
    return name
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Ambil inisial nama: Budi Santoso -> BS
  static String inisial(String name) {
    final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  // === ALAMAT ===

  /// Format alamat lengkap
  static String formatAlamat({
    required String alamat,
    String? rt,
    String? rw,
    String? kelurahan,
    String? kecamatan,
    String? kota,
  }) {
    final parts = <String>[alamat];
    if (rt != null && rw != null) parts.add('RT $rt/RW $rw');
    if (kelurahan != null) parts.add('Kel. $kelurahan');
    if (kecamatan != null) parts.add('Kec. $kecamatan');
    if (kota != null) parts.add(kota);
    return parts.join(', ');
  }

  // === FILE SIZE ===

  /// Format ukuran file: 1.5 MB
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // === GENERAL ===

  /// Truncate text: "Ini adalah teks panjang..." -> "Ini adalah te..."
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
