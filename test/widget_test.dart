import 'package:flutter_test/flutter_test.dart';
import 'package:easylens/main.dart';

void main() {
  testWidgets('Welcome Screen Title Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EasyLensApp());

    // Verify that the title BUDDY is present on the welcome screen
    expect(find.text('BUDDY'), findsOneWidget);
  });
}
