import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/app.dart';

void main() {
  testWidgets('renders auth page when there is no signed in user', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsWidgets);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Crear base inicial'), findsOneWidget);
  });
}
