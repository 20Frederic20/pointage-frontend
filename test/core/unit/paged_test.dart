import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/paged.dart';

void main() {
  test('fromJson maps every item and keeps the total', () {
    final page = Paged.fromJson({'items': [{'v': 1}, {'v': 2}], 'total': 7}, (j) => j['v'] as int);
    expect(page.items, [1, 2]);
    expect(page.total, 7);
  });
}
