import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<FirebaseApp> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = Firebase.initializeApp().timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException(
        'Firebase no respondio durante el arranque. Revisa la configuracion y la conexion del emulador.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapShell(
            child: _BootstrapMessage(
              title: 'Iniciando aplicacion',
              message: 'Conectando Firebase...',
              showProgress: true,
            ),
          );
        }

        if (snapshot.hasError) {
          return _BootstrapShell(
            child: _BootstrapMessage(
              title: 'No se pudo iniciar la app',
              message: '${snapshot.error}',
            ),
          );
        }

        return MyApp();
      },
    );
  }
}

class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF4EFE6),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootstrapMessage extends StatelessWidget {
  const _BootstrapMessage({
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B3C49),
          ),
        ),
        const SizedBox(height: 12),
        Text(message),
        if (showProgress) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}
