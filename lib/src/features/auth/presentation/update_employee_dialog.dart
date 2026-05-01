import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/role_permissions.dart';

class UpdateEmployeeRequest {
  const UpdateEmployeeRequest({
    required this.fullName,
    required this.phone,
    required this.branchId,
    required this.role,
    required this.isActive,
  });

  final String fullName;
  final String phone;
  final String branchId;
  final UserRole role;
  final bool isActive;
}

class UpdateEmployeeDialog extends StatefulWidget {
  const UpdateEmployeeDialog({
    super.key,
    required this.employee,
    required this.branches,
    required this.canChangeRoleOrStatus,
  });

  final AppUser employee;
  final List<Branch> branches;
  final bool canChangeRoleOrStatus;

  @override
  State<UpdateEmployeeDialog> createState() => _UpdateEmployeeDialogState();
}

class _UpdateEmployeeDialogState extends State<UpdateEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;

  late UserRole _selectedRole;
  late String _selectedBranchId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.employee.fullName);
    _phoneController = TextEditingController(text: widget.employee.phone);
    _selectedRole = widget.employee.role;
    _selectedBranchId = widget.employee.branchId;
    _isActive = widget.employee.isActive;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      UpdateEmployeeRequest(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        branchId: _selectedBranchId,
        role: _selectedRole,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: const Color(0xFF121318),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppPalette.panelBorder),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gestionar empleado',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
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
                TextFormField(
                  initialValue: widget.employee.email,
                  enabled: false,
                  style: const TextStyle(color: AppPalette.textMuted),
                  decoration: const InputDecoration(labelText: 'Correo'),
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
                  onChanged: widget.canChangeRoleOrStatus
                      ? (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedRole = value;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBranchId,
                  dropdownColor: AppPalette.storm,
                  style: const TextStyle(color: AppPalette.textPrimary),
                  decoration: const InputDecoration(labelText: 'Sucursal'),
                  items: widget.branches
                      .map(
                        (branch) => DropdownMenuItem<String>(
                          value: branch.id,
                          child: Text(branch.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedBranchId = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Empleado activo'),
                  value: _isActive,
                  activeTrackColor: AppPalette.amber,
                  onChanged: widget.canChangeRoleOrStatus
                      ? (value) {
                          setState(() {
                            _isActive = value;
                          });
                        }
                      : null,
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
                        onPressed: _submit,
                        child: const Text('Guardar cambios'),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}
