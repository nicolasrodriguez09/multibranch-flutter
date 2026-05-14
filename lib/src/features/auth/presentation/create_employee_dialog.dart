import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/role_permissions.dart';

class CreateEmployeeRequest {
  const CreateEmployeeRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.phone,
    required this.branchId,
    required this.role,
  });

  final String fullName;
  final String email;
  final String password;
  final String phone;
  final String branchId;
  final UserRole role;
}

class CreateEmployeeDialog extends StatefulWidget {
  const CreateEmployeeDialog({super.key, required this.branches});

  final List<Branch> branches;

  @override
  State<CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<CreateEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.seller;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    if (widget.branches.isNotEmpty) {
      _selectedBranchId = widget.branches.first.id;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final branchId = _selectedBranchId;
    if (branchId == null) {
      return;
    }

    Navigator.of(context).pop(
      CreateEmployeeRequest(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim(),
        branchId: branchId,
        role: _selectedRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = widget.branches;
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xEE151016), Color(0xEE08090C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppPalette.panelBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 36,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1F7FD1FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppPalette.panelBorder),
                  ),
                  child: Text(
                    'ALTA DE EMPLEADO',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppPalette.cyan,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingresar nuevo empleado',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mantiene la misma identidad visual del login, pero enfocado en altas rapidas y claras.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppPalette.textMuted,
                  ),
                ),
                const SizedBox(height: 22),
                _field(
                  controller: _fullNameController,
                  label: 'Nombre completo',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre completo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _emailController,
                  label: 'Correo',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el correo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _phoneController,
                  label: 'Telefono',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  dropdownColor: AppPalette.storm,
                  style: const TextStyle(color: AppPalette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: UserRole.values
                      .map(
                        (role) => DropdownMenuItem<UserRole>(
                          value: role,
                          child: Text(role.displayName),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBranchId,
                  dropdownColor: AppPalette.storm,
                  style: const TextStyle(color: AppPalette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Sucursal'),
                  items: branches
                      .map(
                        (branch) => DropdownMenuItem<String>(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: branches.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedBranchId = value;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Selecciona una sucursal.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _passwordController,
                  label: 'Contrasena temporal',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa una contrasena.';
                    }
                    if (value.length < 6) {
                      return 'Usa al menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _confirmPasswordController,
                  label: 'Confirmar contrasena',
                  obscureText: true,
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Las contrasenas no coinciden.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppPalette.panelBorder),
                          foregroundColor: AppPalette.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: branches.isEmpty ? null : _submit,
                        child: const Text('Crear empleado'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}
