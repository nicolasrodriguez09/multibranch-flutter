import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_multibranch_proyect/src/app.dart';
import 'package:flutter_multibranch_proyect/src/features/auth/application/auth_service.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/application/inventory_workflow_service.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/data/sample_seed_data.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/domain/models.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/branch_directory_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/branch_location_resolver.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/inventory_dashboard_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/notifications_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/product_detail_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/request_tracking_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/reservation_request_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/sync_status_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/stock_alerts_page.dart';
import 'package:flutter_multibranch_proyect/src/features/inventory/presentation/transfer_request_page.dart';

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
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Notificaciones'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Alertas de stock'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Estado de sincronizacion'),
      ),
      findsOneWidget,
    );
    expect(find.text('Bandeja de aprobaciones'), findsWidgets);
    expect(find.text('Trazabilidad operativa'), findsOneWidget);
    expect(find.text('Agregar sucursal'), findsOneWidget);
    expect(find.text('Crear base de datos inicial'), findsOneWidget);
    expect(find.text('Cerrar sesion'), findsOneWidget);

    await tester.tap(find.text('Gestion de empleados'));
    await tester.pumpAndSettle();

    expect(find.text('Empleados registrados'), findsOneWidget);
    expect(find.text('Nuevo empleado'), findsOneWidget);
    expect(find.text('Ana Admin'), findsOneWidget);
  });

  testWidgets('admin can open traceability module from drawer', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await _seedUserProfile(
      firestore,
      uid: 'uid_admin_trace',
      fullName: 'Ana Admin',
      email: 'admintrace@empresa.com',
      role: 'admin',
      branchId: 'branch_001',
    );

    await tester.pumpWidget(
      MyApp(
        firestore: firestore,
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(
            uid: 'uid_admin_trace',
            email: 'admintrace@empresa.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Trazabilidad operativa'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trazabilidad operativa'));
    await tester.pumpAndSettle();

    expect(find.text('Trazabilidad operativa'), findsOneWidget);
    expect(
      find.text('Trazabilidad de traslados y solicitudes'),
      findsOneWidget,
    );
    expect(find.text('Traslados auditados'), findsOneWidget);
    expect(find.text('Solicitudes auditadas'), findsOneWidget);
  });

  testWidgets(
    'admin can open transfer traceability detail from audit activity',
    (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      var currentTime = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => currentTime,
      );
      final sampleData = SampleSeedData.build(currentTime);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final admin = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.adminUser,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 2,
        reason: 'Venta prioritaria',
        notes: 'Cliente confirmado en caja',
      );
      await service.approveTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
      );

      final authService = AuthService(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: admin.id, email: admin.email),
        ),
        firestore: firestore,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: InventoryDashboardPage(
            service: service,
            authService: authService,
            currentUser: admin,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Actividad administrativa'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Traslado aprobado').first);
      await tester.pumpAndSettle();

      expect(find.text('Trazabilidad del traslado'), findsOneWidget);
      expect(find.text('Ruta del movimiento'), findsOneWidget);
      expect(find.text('Actores clave'), findsOneWidget);
      expect(find.text('Timeline auditado'), findsOneWidget);
      expect(find.textContaining('Juan Centro'), findsWidgets);
      expect(find.textContaining('Sucursal Norte'), findsWidgets);
    },
  );

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
    await tester.scrollUntilVisible(
      find.text('Prioridades inmediatas'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Prioridades inmediatas'), findsOneWidget);
    expect(find.text('Stock bajo prioritario'), findsOneWidget);
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
    expect(find.text('Sucursales'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Notificaciones'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Alertas de stock'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Estado de sincronizacion'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Estado de solicitudes'),
      ),
      findsOneWidget,
    );
    expect(find.text('Reservar producto'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.widgetWithText(ListTile, 'Solicitar traslado'),
      ),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Solicitar traslado'), findsOneWidget);
  });

  testWidgets(
    'reservation request page creates a pending request in another branch',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      var currentTime = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => currentTime,
      );
      final sampleData = SampleSeedData.build(currentTime);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ReservationRequestPage(
            service: service,
            currentUser: seller,
            initialProductId: DemoIds.phoneProduct,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitar reserva'), findsOneWidget);
      expect(find.text('Formulario de reserva'), findsOneWidget);
      expect(
        find.textContaining('Sin stock local para Samsung A55'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad a reservar'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cliente'),
        'Cliente Reserva Norte',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Telefono del cliente'),
        '3001234567',
      );

      await tester.scrollUntilVisible(
        find.text('Enviar solicitud'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.textContaining('quedo pendiente de aprobacion en Sucursal Norte'),
        findsOneWidget,
      );

      final reservations = await service.reservations
          .watchReservationsByUser(seller.id)
          .first;
      final reservation = reservations.cast<Reservation?>().firstWhere(
        (item) => item?.customerName == 'Cliente Reserva Norte',
        orElse: () => null,
      );

      expect(reservation, isNotNull);
      expect(reservation!.branchId, DemoIds.branchNorth);
      expect(reservation.status, ReservationStatus.pending);
      expect(reservation.quantity, 2);
    },
  );

  testWidgets(
    'transfer request page creates a pending request for seller branch',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      var currentTime = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => currentTime,
      );
      final sampleData = SampleSeedData.build(currentTime);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: TransferRequestPage(
            service: service,
            currentUser: seller,
            initialProductId: DemoIds.phoneProduct,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitar traslado'), findsOneWidget);
      expect(find.text('Formulario de solicitud'), findsOneWidget);
      expect(
        find.textContaining('Sin stock local para Samsung A55'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Cantidad solicitada'),
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Motivo'),
        'Venta comprometida sin stock local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notas internas'),
        'Cliente espera hoy',
      );

      await tester.scrollUntilVisible(
        find.text('Enviar solicitud'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(find.textContaining('hacia Sucursal Centro'), findsOneWidget);

      final transfers = await service.transfers.watchTransfers().first;
      final transfer = transfers.cast<TransferRequest?>().firstWhere(
        (item) => item?.reason == 'Venta comprometida sin stock local',
        orElse: () => null,
      );
      expect(transfer, isNotNull);
      expect(transfer!.requestedBy, DemoIds.branchSeller);
      expect(transfer.fromBranchId, DemoIds.branchNorth);
      expect(transfer.toBranchId, DemoIds.branchCenter);
      expect(transfer.quantity, 2);
    },
  );

  testWidgets(
    'notification inbox shows request outcomes and marks them as read',
    (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => now,
      );
      final sampleData = SampleSeedData.build(now);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 1,
        reason: 'Venta con seguimiento',
      );
      await service.rejectTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
        reviewComment: 'Se prioriza stock para la demanda local.',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: NotificationInboxPage(service: service, currentUser: seller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notificaciones'), findsOneWidget);
      expect(find.text('Solicitud rechazada'), findsOneWidget);
      expect(find.textContaining('Motivo: Se prioriza stock'), findsOneWidget);
      expect(find.text('Marcar leida'), findsOneWidget);

      await tester.ensureVisible(find.text('Marcar leida'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar leida'));
      await tester.pumpAndSettle();

      expect(find.text('Leida'), findsOneWidget);
    },
  );

  testWidgets('sync status page shows api health and branches with issues', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 3, 26, 12, 0);
    final service = InventoryWorkflowService(
      firestore: firestore,
      clock: () => now,
    );
    final sampleData = SampleSeedData.build(now);
    await service.seedMasterData(actorUser: sampleData.users.first);
    final admin = sampleData.users.first;

    await service.system.addSyncLog(
      SyncLog(
        id: 'sync_failed_widget',
        branchId: DemoIds.branchNorth,
        branchName: 'Sucursal Norte',
        type: 'inventory',
        status: 'failed',
        recordsProcessed: 0,
        startedAt: now.subtract(const Duration(minutes: 6)),
        finishedAt: now.subtract(const Duration(minutes: 4)),
        message: 'Timeout con API central.',
        createdAt: now.subtract(const Duration(minutes: 4)),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: SyncStatusPage(service: service, currentUser: admin),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estado de sincronizacion'), findsOneWidget);
    expect(find.text('API de sincronizacion'), findsOneWidget);
    expect(find.text('Alertas de monitoreo'), findsOneWidget);
    expect(find.text('Solicitar reintento'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Reglas de fallo'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Reglas de fallo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ultima sincronizacion por sucursal'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ultima sincronizacion por sucursal'), findsOneWidget);
    expect(find.text('Sucursal Norte'), findsWidgets);
    expect(find.text('Con fallo'), findsWidgets);
  });

  testWidgets('stock alerts page shows alerts and supports read actions', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 3, 26, 12, 0);
    final service = InventoryWorkflowService(
      firestore: firestore,
      clock: () => now,
    );
    final sampleData = SampleSeedData.build(now);
    await service.seedMasterData(actorUser: sampleData.users.first);
    final seller = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.branchSeller,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: StockAlertsPage(service: service, currentUser: seller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alertas de stock'), findsOneWidget);
    expect(find.text('Sin leer'), findsOneWidget);
    expect(find.text('Marcar leida'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Marcar leida').first,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar leida').first);
    await tester.pumpAndSettle();

    expect(find.text('Leida'), findsWidgets);
  });

  testWidgets(
    'request tracking page filters by status and shows status history',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      var currentTime = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => currentTime,
      );
      final sampleData = SampleSeedData.build(currentTime);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final supervisor = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.secondBranchSeller,
      );
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final reservation = await service.createReservation(
        actorUser: seller,
        branchId: DemoIds.branchNorth,
        productId: DemoIds.phoneProduct,
        customerName: 'Cliente Historial',
        customerPhone: '3001112233',
        quantity: 1,
        expiresIn: const Duration(hours: 24),
      );
      await service.approveReservation(
        actorUser: supervisor,
        reservationId: reservation.id,
      );

      currentTime = currentTime.add(const Duration(minutes: 10));
      final transfer = await service.requestTransfer(
        actorUser: seller,
        productId: DemoIds.laptopProduct,
        fromBranchId: DemoIds.branchNorth,
        toBranchId: DemoIds.branchCenter,
        quantity: 1,
        reason: 'Seguimiento en pantalla',
      );
      await service.approveTransfer(
        actorUser: supervisor,
        transferId: transfer.id,
      );
      await service.markTransferInTransit(
        actorUser: supervisor,
        transferId: transfer.id,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: RequestTrackingPage(service: service, currentUser: seller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estado de solicitudes'), findsOneWidget);
      expect(
        find.textContaining('resultado(s) con los filtros actuales.'),
        findsOneWidget,
      );

      final inTransitFilter = find.widgetWithText(ChoiceChip, 'En transito');
      await tester.ensureVisible(inTransitFilter);
      await tester.tap(inTransitFilter);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(inTransitFilter).selected, isTrue);

      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();

      expect(find.text('Historial de cambios'), findsOneWidget);
      expect(find.text('Traslado en transito'), findsOneWidget);
      expect(find.text('Solicitud aprobada'), findsOneWidget);
    },
  );

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
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

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

  testWidgets('product detail page loads commercial and inventory data', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 3, 26, 12, 0);
    final service = InventoryWorkflowService(
      firestore: firestore,
      clock: () => now,
    );
    final sampleData = SampleSeedData.build(now);
    await service.seedMasterData(actorUser: sampleData.users.first);
    final seller = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.branchSeller,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ProductDetailPage(
          service: service,
          currentUser: seller,
          productId: DemoIds.monitorProduct,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Detalle del producto'), findsOneWidget);
    expect(find.text('Monitor Samsung 24'), findsOneWidget);
    expect(find.text('Confiabilidad del dato'), findsOneWidget);
    expect(find.text('Amarillo'), findsOneWidget);
    expect(find.text('Antiguedad 18 min'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Codigo de barras'),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Codigo de barras'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Stock por sucursal'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Stock por sucursal'), findsOneWidget);
    expect(find.text('Sucursal Norte'), findsOneWidget);
    expect(find.text('Rojo vencido'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Atributos del producto'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Atributos del producto'), findsOneWidget);
    expect(find.text('Estado de inventario'), findsOneWidget);
  });

  testWidgets('product detail shows cache message when using local cache', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 3, 26, 12, 0);
    final service = InventoryWorkflowService(
      firestore: firestore,
      clock: () => now,
    );
    final sampleData = SampleSeedData.build(now);
    await service.seedMasterData(actorUser: sampleData.users.first);
    final seller = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.branchSeller,
    );

    await service.fetchProductDetail(
      actorUser: seller,
      branchId: DemoIds.branchCenter,
      productId: DemoIds.monitorProduct,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ProductDetailPage(
          service: service,
          currentUser: seller,
          productId: DemoIds.monitorProduct,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mostrando informacion desde cache local'),
      findsOneWidget,
    );
  });

  testWidgets(
    'branch directory shows selected product stock and branch filters',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => now,
      );
      final sampleData = SampleSeedData.build(now);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: BranchDirectoryPage(
            service: service,
            currentUser: seller,
            selectedProductId: DemoIds.phoneProduct,
            locationResolver: _FakeBranchLocationResolver.granted(
              const BranchLocation(lat: -0.1807, lng: -78.4678),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Directorio de sucursales'), findsOneWidget);
      expect(find.textContaining('Samsung A55'), findsWidgets);
      expect(find.text('Mayor stock'), findsOneWidget);
      expect(find.text('Cercania'), findsOneWidget);
      expect(find.text('Sucursal Norte'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Sucursal Norte')).dy,
        lessThan(tester.getTopLeft(find.text('Sucursal Centro')).dy),
      );

      await tester.tap(find.text('Cercania'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Sucursal Centro')).dy,
        lessThan(tester.getTopLeft(find.text('Sucursal Norte')).dy),
      );

      await tester.tap(find.text('Mayor stock'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Sucursal Norte')).dy,
        lessThan(tester.getTopLeft(find.text('Sucursal Centro')).dy),
      );

      await tester.scrollUntilVisible(
        find.text('Sucursal Centro'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Sucursal Centro'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Con stock'),
        -220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Con stock'));
      await tester.pumpAndSettle();

      expect(find.text('Sucursal Norte'), findsOneWidget);
      expect(find.text('Sucursal Centro'), findsNothing);

      await tester.tap(find.text('Todas').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'norte');
      await tester.pumpAndSettle();

      expect(find.text('Sucursal Norte'), findsOneWidget);
      expect(find.text('Sucursal Centro'), findsNothing);
    },
  );

  testWidgets(
    'branch directory falls back to assigned branch when location permission is denied',
    (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => now,
      );
      final sampleData = SampleSeedData.build(now);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: BranchDirectoryPage(
            service: service,
            currentUser: seller,
            selectedProductId: DemoIds.phoneProduct,
            locationResolver: _FakeBranchLocationResolver.denied(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se concedio el permiso de ubicacion'),
        findsOneWidget,
      );
      expect(find.text('Usar mi ubicacion'), findsOneWidget);
      expect(
        find.textContaining('Distancia desde Sucursal Centro'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'product detail shows alternative branch recommendation and allows switching options',
    (WidgetTester tester) async {
      final firestore = FakeFirebaseFirestore();
      final now = DateTime.utc(2026, 3, 26, 12, 0);
      final service = InventoryWorkflowService(
        firestore: firestore,
        clock: () => now,
      );
      final sampleData = SampleSeedData.build(now);
      await service.seedMasterData(actorUser: sampleData.users.first);
      final admin = sampleData.users.first;
      final seller = sampleData.users.firstWhere(
        (user) => user.id == DemoIds.branchSeller,
      );

      final branchSouth = await service.createBranch(
        actorUser: admin,
        name: 'Sucursal Sur',
        code: 'SUR-003',
        address: 'Av. Sur 120',
        city: 'Quito',
        phone: '023444444',
        email: 'sur@empresa.com',
        managerName: 'Paola Sur',
        openingHours: '09:00-18:00',
        latitude: -0.265,
        longitude: -78.52,
      );

      await service.inventories.upsertInventory(
        InventoryItem.create(
          branchId: branchSouth.id,
          branchName: branchSouth.name,
          productId: DemoIds.phoneProduct,
          productName: 'Samsung A55',
          sku: 'PHN-002',
          stock: 11,
          reservedStock: 0,
          incomingStock: 0,
          minimumStock: 3,
          updatedBy: admin.id,
          isActive: true,
          updatedAt: now.subtract(const Duration(minutes: 8)),
          lastMovementAt: now.subtract(const Duration(minutes: 8)),
          lastSyncAt: now.subtract(const Duration(minutes: 8)),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ProductDetailPage(
            service: service,
            currentUser: seller,
            productId: DemoIds.phoneProduct,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sucursal alternativa sugerida'), findsOneWidget);
      expect(
        find.textContaining('Tu sucursal no tiene stock disponible'),
        findsOneWidget,
      );
      expect(find.text('Sucursal Norte'), findsWidgets);
      expect(find.text('Sucursal Sur'), findsOneWidget);
      expect(find.textContaining('15 uds disponibles'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Sucursal Sur'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Sucursal Sur'));
      await tester.pumpAndSettle();

      expect(find.textContaining('11 uds disponibles'), findsOneWidget);
    },
  );

  testWidgets('product detail page shows error state for invalid product id', (
    WidgetTester tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final now = DateTime.utc(2026, 3, 26, 12, 0);
    final service = InventoryWorkflowService(
      firestore: firestore,
      clock: () => now,
    );
    final sampleData = SampleSeedData.build(now);
    await service.seedMasterData(actorUser: sampleData.users.first);
    final seller = sampleData.users.firstWhere(
      (user) => user.id == DemoIds.branchSeller,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ProductDetailPage(
          service: service,
          currentUser: seller,
          productId: 'missing_product',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el producto'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
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
      expect(find.text('Solicitudes y sincronizacion'), findsWidgets);
      expect(find.text('Modulos habilitados'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(ListTile, 'Notificaciones'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(ListTile, 'Alertas de stock'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(ListTile, 'Estado de sincronizacion'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(ListTile, 'Estado de solicitudes'),
        ),
        findsOneWidget,
      );
      expect(find.text('Bandeja de aprobaciones'), findsWidgets);
      expect(find.text('Reservar producto'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(ListTile, 'KPIs operativos'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consultas sin stock'), findsOneWidget);
      expect(find.text('Solicitudes de traslado por dia'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(ListTile, 'Inventario y alertas'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Productos mas consultados'), findsOneWidget);
      expect(find.text('Productos sin stock'), findsWidgets);
      expect(find.text('Alertas de inventario bajo'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.menu).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(
            ListTile,
            'Solicitudes y sincronizacion',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes y sincronizacion'), findsWidgets);
      expect(find.text('Bandeja de aprobaciones'), findsWidgets);
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

class _FakeBranchLocationResolver implements BranchLocationResolver {
  const _FakeBranchLocationResolver(this._result);

  final BranchLocationAccessResult _result;

  factory _FakeBranchLocationResolver.granted(BranchLocation location) {
    return _FakeBranchLocationResolver(
      BranchLocationAccessResult(
        status: BranchLocationAccessStatus.granted,
        location: location,
        message:
            'Ubicacion actual activa. Las distancias se ordenan desde el dispositivo.',
      ),
    );
  }

  factory _FakeBranchLocationResolver.denied() {
    return const _FakeBranchLocationResolver(
      BranchLocationAccessResult(
        status: BranchLocationAccessStatus.denied,
        message:
            'No se concedio el permiso de ubicacion. Se usa la sucursal asignada como referencia.',
      ),
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<BranchLocationAccessResult> resolveCurrentLocation() async => _result;
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
