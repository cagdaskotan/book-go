import 'package:book_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uygulama açılır', (tester) async {
    await tester.pumpWidget(const BookApp());
  });
}
