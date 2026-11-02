import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void saveFile(Uint8List bytes, String filename, String mimeType) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
