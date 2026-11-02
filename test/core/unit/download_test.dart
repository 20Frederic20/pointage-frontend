import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/download/download.dart';

void main() {
  test('outside the web, saving a file is unsupported', () {
    expect(() => saveFile(Uint8List(0), 'a.csv', 'text/csv'), throwsUnsupportedError);
  });
}
