import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/app.dart';

void main() {
  testWidgets('renders the inventory dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(firestore: FakeFirebaseFirestore()),
    );

    expect(find.text('Base Firestore'), findsOneWidget);
    expect(find.text('Crear base inicial'), findsOneWidget);
    expect(find.text('Colecciones objetivo'), findsOneWidget);
  });
}
