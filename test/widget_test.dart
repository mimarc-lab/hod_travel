import 'package:flutter_test/flutter_test.dart';
import 'package:hod_travel/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HODApp());
    expect(find.byType(HODApp), findsOneWidget);
  });
}
