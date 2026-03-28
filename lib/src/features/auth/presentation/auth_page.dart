import 'package:flutter/material.dart';

import '../../inventory/application/inventory_workflow_service.dart';
import '../application/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.authService,
    required this.inventoryService,
  });

  final AuthService authService;
  final InventoryWorkflowService inventoryService;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isCreatingBase = false;
  String _status = 'Ingresa con tu correo y contrasena.';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _status = 'Iniciando sesion...';
    });

    try {
      await widget.authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _createBaseData() async {
    setState(() {
      _isCreatingBase = true;
      _status = 'Creando base inicial...';
    });

    try {
      await widget.inventoryService.seedMasterData();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Base inicial creada. Ya puedes iniciar sesion con usuarios existentes.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'No se pudo crear la base inicial: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingBase = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF4EFE6),
              Color(0xFFDDE8E4),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login',
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B3C49),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _status,
                            style: textTheme.bodyLarge?.copyWith(color: const Color(0xFF31525B)),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa el correo.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Contrasena',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa la contrasena.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: const Text('Ingresar'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isCreatingBase ? null : _createBaseData,
                              icon: _isCreatingBase
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.storage_outlined),
                              label: const Text('Crear base inicial'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
