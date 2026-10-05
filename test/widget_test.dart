import 'package:flutter_test/flutter_test.dart';
import 'package:synrec/main.dart';

void main() {
  testWidgets('SynRec app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SynRecApp());
    expect(find.textContaining('SynRec'), findsWidgets);
  });
}
