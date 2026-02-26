import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ferri/app.dart';

void main() {
  testWidgets('FerriApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FerriApp()));

    expect(find.text('Ferri'), findsOneWidget);
  });
}
