import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';

void main() {
  testWidgets('shows sign-in when there is no authenticated session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LifeOsApp());

    expect(find.text('Entrar'), findsOneWidget);
  });
}
