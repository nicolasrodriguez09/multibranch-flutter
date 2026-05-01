import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../domain/models.dart';

class CreateBranchRequest {
  const CreateBranchRequest({
    required this.name,
    required this.code,
    required this.address,
    required this.city,
    required this.phone,
    required this.email,
    required this.managerName,
    required this.openingHours,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String code;
  final String address;
  final String city;
  final String phone;
  final String email;
  final String managerName;
  final String openingHours;
  final double latitude;
  final double longitude;
}

class CreateBranchDialog extends StatefulWidget {
  const CreateBranchDialog({super.key, this.initialBranch});

  final Branch? initialBranch;

  @override
  State<CreateBranchDialog> createState() => _CreateBranchDialogState();
}

class _CreateBranchDialogState extends State<CreateBranchDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _managerController = TextEditingController();
  final _hoursController = TextEditingController(text: '08:00-18:00');
  final _latitudeController = TextEditingController(text: '0');
  final _longitudeController = TextEditingController(text: '0');

  bool get _isEditing => widget.initialBranch != null;

  @override
  void initState() {
    super.initState();
    final branch = widget.initialBranch;
    if (branch != null) {
      _nameController.text = branch.name;
      _codeController.text = branch.code;
      _addressController.text = branch.address;
      _cityController.text = branch.city;
      _phoneController.text = branch.phone;
      _emailController.text = branch.email;
      _managerController.text = branch.managerName;
      _hoursController.text = branch.openingHours;
      _latitudeController.text = branch.location.lat.toString();
      _longitudeController.text = branch.location.lng.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _managerController.dispose();
    _hoursController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      CreateBranchRequest(
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        managerName: _managerController.text.trim(),
        openingHours: _hoursController.text.trim(),
        latitude: double.tryParse(_latitudeController.text.trim()) ?? 0,
        longitude: double.tryParse(_longitudeController.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
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
                    color: const Color(0x1FFF8A24),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppPalette.panelBorder),
                  ),
                  child: Text(
                    _isEditing ? 'EDITAR SUCURSAL' : 'NUEVA SUCURSAL',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppPalette.amberSoft,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditing ? 'Editar sucursal' : 'Agregar sucursal',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                _field(
                  controller: _nameController,
                  label: 'Nombre',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre de la sucursal.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _codeController,
                  label: 'Codigo',
                  enabled: !_isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un codigo.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _addressController,
                  label: 'Direccion',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa la direccion.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _cityController,
                  label: 'Ciudad',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa la ciudad.';
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
                _field(
                  controller: _emailController,
                  label: 'Correo',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _field(controller: _managerController, label: 'Responsable'),
                const SizedBox(height: 16),
                _field(controller: _hoursController, label: 'Horario'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _latitudeController,
                        label: 'Latitud',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        controller: _longitudeController,
                        label: 'Longitud',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                  ],
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
                        child: Text(
                          _isEditing ? 'Guardar cambios' : 'Crear sucursal',
                        ),
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
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }
}
