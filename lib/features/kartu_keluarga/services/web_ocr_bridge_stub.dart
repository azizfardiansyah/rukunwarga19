import 'dart:typed_data';

Future<String> runWebOcrImpl(
  Uint8List imageBytes, {
  String lang = 'ind+eng',
}) async {
  throw UnsupportedError('Web OCR bridge hanya tersedia pada platform web.');
}

