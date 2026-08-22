import 'package:flutter_test/flutter_test.dart';
import 'package:family_tree/main.dart';

void main() {
  testWidgets('Family tree app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FamilyTreeApp());

    // Verify that the app builds successfully
    expect(find.text('Family Tree'), findsOneWidget);
  });
}
