import 'package:book_app/utils/isbn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts valid ISBN-13 book barcodes', () {
    expect(isValidBookISBN13('9789750738609'), isTrue);
    expect(isValidBookISBN13('9791234567896'), isTrue);
  });

  test('rejects non-book and invalid EAN values', () {
    expect(isValidBookISBN13('8690504012345'), isFalse);
    expect(isValidBookISBN13('9789750738608'), isFalse);
    expect(isValidBookISBN13('1234567890123'), isFalse);
  });
}
