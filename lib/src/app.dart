import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'features/auth/application/auth_service.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/inventory/application/inventory_workflow_service.dart';
import 'features/inventory/domain/models.dart';
import 'features/inventory/presentation/inventory_dashboard_page.dart';

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        authService = AuthService(
          auth: auth ?? FirebaseAuth.instance,
          firestore: firestore ?? FirebaseFirestore.instance,
        ),
        inventoryService = InventoryWorkflowService(
          firestore: firestore ?? FirebaseFirestore.instance,
        );

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final AuthService authService;
  final InventoryWorkflowService inventoryService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF005F73),
      primary: const Color(0xFF005F73),
      secondary: const Color(0xFFEE9B00),
      surface: const Color(0xFFF6F1E8),
    );

    return MaterialApp(
      title: 'Multi-Branch Inventory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4EFE6),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: _AuthGate(
        authService: authService,
        inventoryService: inventoryService,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.authService,
    required this.inventoryService,
  });

  final AuthService authService;
  final InventoryWorkflowService inventoryService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Validando sesion...');
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
              return const _LoadingScreen(message: 'Cargando perfil...');
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return _MissingProfilePage(authService: authService);
            }

            if (!profile.isActive) {
              return _InactiveUserPage(authService: authService);
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

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _MissingProfilePage extends StatelessWidget {
  const _MissingProfilePage({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'La cuenta existe en Firebase Auth, pero no tiene perfil en Firestore.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: authService.signOut,
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InactiveUserPage extends StatelessWidget {
  const _InactiveUserPage({required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tu usuario esta inactivo. Contacta al administrador.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: authService.signOut,
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
