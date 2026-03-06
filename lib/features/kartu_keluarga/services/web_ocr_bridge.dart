import 'dart:typed_data';

import 'web_ocr_bridge_stub.dart'
    if (dart.library.html) 'web_ocr_bridge_web.dart';

Future<String> runWebOcr(
  Uint8List imageBytes, {
  String lang = 'ind+eng',
}) {
  return runWebOcrImpl(imageBytes, lang: lang);
}

