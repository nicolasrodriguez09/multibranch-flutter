import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/app.dart';

void main() {
  testWidgets('renders auth page when there is no signed in user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(firestore: FakeFirebaseFirestore(), auth: MockFirebaseAuth()),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Conecta y gestiona tu inventario entre sucursales.'),
      findsOneWidget,
    );
    expect(find.text('Iniciar Sesion'), findsOneWidget);

    await tester.ensureVisible(find.text('Iniciar Sesion'));
    await tester.tap(find.text('Iniciar Sesion'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio de sesion'), findsOneWidget);
    expect(find.text('Correo corporativo'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('admin dashboard exposes administrative modules only for admin', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedUserProfile(
      firestore,
      uid: 'uid_admin',
      fullName: 'Ana Admin',
      email: 'admin@empresa.com',
      role: 'admin',
      branchId: 'branch_001',
    );

    await tester.pumpWidget(
      MyApp(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid_admin', email: 'admin@empresa.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Administrativo'), findsOneWidget);
    expect(find.text('Sincronizacion operativa'), findsOneWidget);
    expect(find.text('Metricas'), findsOneWidget);
    expect(find.text('Control administrativo'), findsNothing);
    expect(find.text('Acciones administrativas'), findsNothing);
    expect(find.text('Matriz de permisos'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Actualizar datos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Solicitudes pendientes'), findsOneWidget);
    expect(find.text('KPIs de supervision'), findsOneWidget);
    expect(find.text('Consultas sin stock'), findsOneWidget);
    expect(find.text('Solicitudes de traslado por dia'), findsOneWidget);
    expect(find.text('Actividad administrativa'), findsOneWidget);
    expect(find.text('Actualizar datos'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Menu administrativo'), findsOneWidget);
    expect(find.text('Gestion de empleados'), findsOneWidget);
    expect(find.text('Agregar sucursal'), findsOneWidget);
    expect(find.text('Crear base de datos inicial'), findsOneWidget);
    expect(find.text('Cerrar sesion'), findsOneWidget);

    await tester.tap(find.text('Gestion de empleados'));
    await tester.pumpAndSettle();

    expect(find.text('Empleados registrados'), findsOneWidget);
    expect(find.text('Nuevo empleado'), findsOneWidget);
    expect(find.text('Ana Admin'), findsOneWidget);
  });

  testWidgets('seller dashboard hides admin and supervisor sections', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedUserProfile(
      firestore,
      uid: 'uid_seller',
      fullName: 'Juan Seller',
      email: 'seller@empresa.com',
      role: 'seller',
      branchId: 'branch_001',
    );

    await tester.pumpWidget(
      MyApp(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'uid_seller', email: 'seller@empresa.com'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panel de ventas'), findsOneWidget);
    expect(find.text('Resumen comercial'), findsOneWidget);
    expect(find.text('KPIs operativos'), findsNothing);
    expect(find.text('Consultas sin stock'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Productos mas consultados'), findsNothing);
    expect(find.text('Ultimas sincronizaciones'), findsNothing);
    expect(find.text('Crear base inicial'), findsNothing);
    expect(find.text('Ingresar nuevo empleado'), findsNothing);
    expect(find.text('Matriz de permisos'), findsNothing);
    expect(find.text('Usuarios'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    expect(find.text('Menu de ventas'), findsOneWidget);
    expect(find.text('Inventario y alertas'), findsOneWidget);
    expect(find.text('Compromisos y sincronizacion'), findsOneWidget);
    expect(find.text('Modulos habilitados'), findsOneWidget);

    await tester.tap(find.text('Inventario y alertas').first);
    await tester.pumpAndSettle();

    expect(find.text('Productos mas consultados'), findsOneWidget);
    expect(find.text('Productos sin stock'), findsWidgets);
    expect(find.text('Alertas de inventario bajo'), findsOneWidget);
    expect(find.text('Compromisos activos'), findsNothing);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compromisos y sincronizacion').first);
    await tester.pumpAndSettle();

    expect(find.text('Compromisos activos'), findsOneWidget);
    expect(find.text('Ultimas sincronizaciones'), findsOneWidget);
  });

  testWidgets('search screen opens from dashboard and handles debounce', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedUserProfile(
      firestore,
      uid: 'uid_seller_search',
      fullName: 'Julia Search',
      email: 'search@empresa.com',
      role: 'seller',
      branchId: 'branch_001',
    );

    await tester.pumpWidget(
      MyApp(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(
            uid: 'uid_seller_search',
            email: 'search@empresa.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Buscar productos'), findsOneWidget);
    expect(find.text('Buscador de productos'), findsOneWidget);
    expect(find.text('Filtros guardados'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'router');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Sin resultados'), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Filtros avanzados'), findsOneWidget);
    expect(find.text('Categoria'), findsOneWidget);
    expect(find.text('Marca'), findsOneWidget);
    expect(find.text('Sucursal'), findsOneWidget);
    expect(find.text('Disponibilidad'), findsOneWidget);
    expect(find.text('Guardar favorito'), findsOneWidget);
  });

  testWidgets(
    'supervisor dashboard exposes operational sections without admin controls',
    (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedUserProfile(
        firestore,
        uid: 'uid_supervisor',
        fullName: 'Maria Supervisor',
        email: 'supervisor@empresa.com',
        role: 'supervisor',
        branchId: 'branch_002',
      );

      await tester.pumpWidget(
        MyApp(
          firestore: firestore,
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'uid_supervisor',
              email: 'supervisor@empresa.com',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Control de sucursal'), findsOneWidget);
      expect(find.text('Resumen operativo'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('KPIs operativos'), findsNothing);
      expect(find.text('Productos mas consultados'), findsNothing);
      expect(find.text('Solicitudes pendientes'), findsNothing);
      expect(find.text('Crear base inicial'), findsNothing);
      expect(find.text('Ingresar nuevo empleado'), findsNothing);
      expect(find.text('Matriz de permisos'), findsNothing);

      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();

      expect(find.text('Menu de sucursal'), findsOneWidget);
      expect(find.text('KPIs operativos'), findsOneWidget);
      expect(find.text('Inventario y alertas'), findsOneWidget);
      expect(find.text('Solicitudes y sincronizacion'), findsOneWidget);
      expect(find.text('Modulos habilitados'), findsOneWidget);

      await tester.tap(find.text('KPIs operativos').first);
      await tester.pumpAndSettle();

      expect(find.text('Consultas sin stock'), findsOneWidget);
      expect(find.text('Solicitudes de traslado por dia'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inventario y alertas').first);
      await tester.pumpAndSettle();

      expect(find.text('Productos mas consultados'), findsOneWidget);
      expect(find.text('Productos sin stock'), findsWidgets);
      expect(find.text('Alertas de inventario bajo'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Solicitudes y sincronizacion').first);
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes pendientes'), findsWidgets);
      expect(find.text('Ultimas sincronizaciones'), findsOneWidget);
    },
  );

  testWidgets(
    'supervisor dashboard drag refresh does not throw visual exceptions',
    (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      await _seedUserProfile(
        firestore,
        uid: 'uid_supervisor_drag',
        fullName: 'Mario Supervisor',
        email: 'supervisor2@empresa.com',
        role: 'supervisor',
        branchId: 'branch_002',
      );

      await tester.pumpWidget(
        MyApp(
          firestore: firestore,
          auth: MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(
              uid: 'uid_supervisor_drag',
              email: 'supervisor2@empresa.com',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, 260));
      await tester.pump();
      await tester.drag(scrollable, const Offset(0, -320));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _seedUserProfile(
  FakeFirebaseFirestore firestore, {
  required String uid,
  required String fullName,
  required String email,
  required String role,
  required String branchId,
}) {
  return firestore.collection('users').doc(uid).set({
    'fullName': fullName,
    'email': email,
    'phone': '',
    'role': role,
    'branchId': branchId,
    'isActive': true,
    'photoUrl': '',
    'lastLoginAt': null,
    'createdAt': null,
    'updatedAt': null,
  });
}
