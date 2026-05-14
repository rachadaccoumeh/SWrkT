import 'package:flutter_test/flutter_test.dart';
import 'package:swrkt/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const App(isDarkMode: true));
    expect(find.byType(App), findsOneWidget);
  });
}