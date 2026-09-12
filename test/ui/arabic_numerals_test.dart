import 'package:flutter_test/flutter_test.dart';
import 'package:meen_al_atlasy/ui/arabic_numerals.dart';

void main() {
  test('1234.ar() == ١٢٣٤', () {
    expect(1234.ar(), '١٢٣٤');
  });

  test('(-5).ar() == -٥', () {
    expect((-5).ar(), '-٥');
  });

  test('arDigits() converts digits inside a string', () {
    expect('جولة 3/8'.arDigits(), 'جولة ٣/٨');
  });
}
