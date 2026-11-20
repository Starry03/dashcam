import 'package:flutter_test/flutter_test.dart';

import 'package:dashcam/main.dart';

void main() {
  testWidgets('Dashcam UI shows start state', (WidgetTester tester) async {
    await tester.pumpWidget(const DashcamApp());

    expect(find.text('START RECORDING'), findsOneWidget);
  });
}
