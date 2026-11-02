import 'dart:typed_data';

import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart' as impl;

/// Fait télécharger [bytes] au navigateur sous [filename].
/// Hors web (application mobile), lève [UnsupportedError] : les exports sont une fonction du back-office.
void saveFile(Uint8List bytes, String filename, String mimeType) => impl.saveFile(bytes, filename, mimeType);
