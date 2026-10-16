import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/core/layout/breakpoints.dart';

void main() {
  test('window sizes switch exactly at 600 and 1024 px', () {
    expect(Breakpoints.fromWidth(599), WindowSize.compact);
    expect(Breakpoints.fromWidth(600), WindowSize.medium);
    expect(Breakpoints.fromWidth(1023), WindowSize.medium);
    expect(Breakpoints.fromWidth(1024), WindowSize.expanded);
  });
}
