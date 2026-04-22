import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/auth/application/auth_session.dart';
import 'features/auth/application/auth_service.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/inventory/application/inventory_workflow_service.dart';
import 'features/inventory/data/inventory_offline_cache.dart';
import 'features/inventory/domain/models.dart';
import 'features/inventory/presentation/inventory_dashboard_page.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.firestore,
    this.auth,
    this.offlineCache,
    this.secureSessionStore,
    this.sessionSnapshotResolver,
    this.enableSessionRefreshMonitoring = true,
  });

  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final InventoryOfflineCache? offlineCache;
  final SecureSessionStore? secureSessionStore;
  final AuthSessionSnapshotResolver? sessionSnapshotResolver;
  final bool enableSessionRefreshMonitoring;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final FirebaseFirestore firestore;
  late final FirebaseAuth auth;
  late final AuthService authService;
  late final InventoryWorkflowService inventoryService;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    firestore = widget.firestore ?? FirebaseFirestore.instance;
    auth = widget.auth ?? FirebaseAuth.instance;
    authService = AuthService(
      auth: auth,
      firestore: firestore,
      secureSessionStore:
          widget.secureSessionStore ?? FlutterSecureSessionStore(),
      sessionSnapshotResolver: widget.sessionSnapshotResolver,
      enableSessionRefreshMonitoring: widget.enableSessionRefreshMonitoring,
    );
    inventoryService = InventoryWorkflowService(
      firestore: firestore,
      offlineCache: widget.offlineCache ?? MemoryInventoryOfflineCache(),
    );
    _authSubscription = authService.authStateChanges().listen(_handleAuthState);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    unawaited(authService.dispose());
    super.dispose();
  }

  void _handleAuthState(User? user) {
    if (user != null) {
      return;
    }

    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil<void>(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            return _AuthGate(
              authService: authService,
              inventoryService: inventoryService,
            );
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }

    final notice = authService.takePendingSessionNotice();
    if (notice == null || notice.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _navigatorKey.currentContext;
      if (context == null) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(notice),
            backgroundColor: const Color(0xFF9B2226),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Multi-Branch Inventory',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _AuthGate(
        authService: authService,
        inventoryService: inventoryService,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.authService, required this.inventoryService});

  final AuthService authService;
  final InventoryWorkflowService inventoryService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SystemStatePage(
            title: 'Validando sesion',
            message: 'Conectando tus credenciales con la plataforma.',
            badge: 'SINCRONIZANDO',
            icon: Icons.shield_outlined,
            showProgress: true,
          );
        }

        final firebaseUser = authSnapshot.data;
        if (firebaseUser == null) {
          return AuthPage(
            authService: authService,
            inventoryService: inventoryService,
          );
        }

        return StreamBuilder<AppUser?>(
          stream: authService.watchProfile(firebaseUser.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _SystemStatePage(
                title: 'Cargando perfil',
                message:
                    'Recuperando permisos, sucursal y modulos disponibles.',
                badge: 'PERFIL',
                icon: Icons.account_circle_outlined,
                showProgress: true,
              );
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return _SystemStatePage(
                title: 'Perfil no encontrado',
                message:
                    'La cuenta existe en Firebase Auth, pero no tiene perfil en Firestore.',
                badge: 'ERROR DE PERFIL',
                icon: Icons.person_search_outlined,
                actionLabel: 'Cerrar sesion',
                onAction: authService.signOut,
              );
            }

            if (!profile.isActive) {
              return _SystemStatePage(
                title: 'Usuario inactivo',
                message: 'Tu usuario esta inactivo. Contacta al administrador.',
                badge: 'ACCESO BLOQUEADO',
                icon: Icons.lock_person_outlined,
                actionLabel: 'Cerrar sesion',
                onAction: authService.signOut,
              );
            }

            return InventoryDashboardPage(
              service: inventoryService,
              authService: authService,
              currentUser: profile,
            );
          },
        );
      },
    );
  }
}

class _SystemStatePage extends StatelessWidget {
  const _SystemStatePage({
    required this.title,
    required this.message,
    required this.badge,
    required this.icon,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String badge;
  final IconData icon;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          const _SystemBackdrop(),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xCC11284C), Color(0xCC08172D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppPalette.panelBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66050E1E),
                          blurRadius: 36,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x1FFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppPalette.panelBorder),
                          ),
                          child: Text(
                            badge,
                            style: textTheme.labelMedium?.copyWith(
                              color: AppPalette.cyan,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppPalette.blue,
                                    AppPalette.blueDark,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(icon, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    message,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: AppPalette.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (showProgress) ...[
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: const LinearProgressIndicator(
                              minHeight: 8,
                              backgroundColor: Color(0x22000000),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppPalette.amber,
                              ),
                            ),
                          ),
                        ],
                        if (actionLabel != null && onAction != null) ...[
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: onAction,
                            child: Text(actionLabel!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBackdrop extends StatelessWidget {
  const _SystemBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.midnight, AppPalette.ocean, AppPalette.deepNavy],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: const [
          _GlowBubble(
            alignment: Alignment.topCenter,
            color: Color(0x552C7BFF),
            size: 340,
            offsetY: -110,
          ),
          _GlowBubble(
            alignment: Alignment.centerLeft,
            color: Color(0x33A4F1FF),
            size: 260,
            offsetX: -110,
          ),
          _GlowBubble(
            alignment: Alignment.bottomRight,
            color: Color(0x44FF8B2C),
            size: 260,
            offsetX: 120,
            offsetY: 90,
          ),
        ],
      ),
    );
  }
}

class _GlowBubble extends StatelessWidget {
  const _GlowBubble({
    required this.alignment,
    required this.color,
    required this.size,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double offsetX;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(offsetX, offsetY),
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, Colors.transparent]),
            ),
          ),
        ),
      ),
    );
  }
}
