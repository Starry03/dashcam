import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('Dashcam UI shows start state', (WidgetTester tester) async {
    await tester.pumpWidget(const DashcamApp());

    expect(find.text('READY'), findsOneWidget);
    expect(find.text('Lock Clip'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
  });
}
