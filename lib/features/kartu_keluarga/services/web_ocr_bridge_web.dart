// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

Future<String> runWebOcrImpl(
  Uint8List imageBytes, {
  String lang = 'ind+eng',
}) async {
  final tesseractAny = globalContext['Tesseract'];
  if (tesseractAny == null || !tesseractAny.isA<JSObject>()) {
    throw Exception('Engine OCR web belum termuat. Refresh aplikasi lalu coba lagi.');
  }
  final tesseract = tesseractAny as JSObject;

  final blob = html.Blob(<Object>[imageBytes], 'image/*');
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  try {
    final promise = tesseract.callMethod<JSPromise<JSAny?>>(
      'recognize'.toJS,
      objectUrl.toJS,
      lang.toJS,
    );
    final resultAny = await promise.toDart;
    if (resultAny == null || !resultAny.isA<JSObject>()) return '';
    final result = resultAny as JSObject;

    final dataAny = result.getProperty<JSAny?>('data'.toJS);
    if (dataAny == null || !dataAny.isA<JSObject>()) return '';
    final data = dataAny as JSObject;

    final textAny = data.getProperty<JSAny?>('text'.toJS);
    if (textAny == null || !textAny.isA<JSString>()) return '';
    return (textAny as JSString).toDart.trim();
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }
}
