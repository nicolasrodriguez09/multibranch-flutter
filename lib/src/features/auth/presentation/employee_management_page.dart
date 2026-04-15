import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../inventory/domain/models.dart';
import '../../inventory/domain/role_permissions.dart';
import '../application/auth_service.dart';
import 'create_employee_dialog.dart';
import 'update_employee_dialog.dart';

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({
    super.key,
    required this.authService,
    required this.currentUser,
  });

  final AuthService authService;
  final AppUser currentUser;

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  bool _isCreatingEmployee = false;
  String? _updatingEmployeeId;

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreateEmployeeDialog(List<Branch> branches) async {
    final request = await showDialog<CreateEmployeeRequest>(
      context: context,
      builder: (context) => CreateEmployeeDialog(branches: branches),
    );

    if (request == null) {
      return;
    }

    setState(() {
      _isCreatingEmployee = true;
    });

    try {
      await widget.authService.createEmployee(
        currentUser: widget.currentUser,
        fullName: request.fullName,
        email: request.email,
        password: request.password,
        phone: request.phone,
        branchId: request.branchId,
        role: request.role,
      );

      if (!mounted) {
        return;
      }
      _showStatusMessage(
        'Empleado creado correctamente: ${request.email} (${request.role.displayName}).',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo crear el empleado: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingEmployee = false;
        });
      }
    }
  }

  Future<void> _openUpdateEmployeeDialog(
    AppUser employee,
    List<Branch> branches,
  ) async {
    final request = await showDialog<UpdateEmployeeRequest>(
      context: context,
      builder: (context) => UpdateEmployeeDialog(
        employee: employee,
        branches: branches,
        canChangeRoleOrStatus: employee.id != widget.currentUser.id,
      ),
    );

    if (request == null) {
      return;
    }

    setState(() {
      _updatingEmployeeId = employee.id;
    });

    try {
      final updatedEmployee = await widget.authService.updateEmployee(
        currentUser: widget.currentUser,
        userId: employee.id,
        fullName: request.fullName,
        phone: request.phone,
        role: request.role,
        branchId: request.branchId,
        isActive: request.isActive,
      );

      if (!mounted) {
        return;
      }
      _showStatusMessage(
        'Empleado actualizado: ${updatedEmployee.fullName} (${updatedEmployee.role.displayName}).',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showStatusMessage('No se pudo actualizar el empleado: $error');
    } finally {
      if (mounted) {
        setState(() {
          _updatingEmployeeId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentUser.can(AppPermission.manageEmployees)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestion de empleados')),
        body: const Center(
          child: Text('No tienes permiso para gestionar empleados.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de empleados')),
      body: Container(
        color: const Color(0xFF08172D),
        child: SafeArea(
          top: false,
          child: StreamBuilder<List<Branch>>(
            stream: widget.authService.catalog.watchBranches(),
            builder: (context, branchSnapshot) {
              final branches = branchSnapshot.data ?? const <Branch>[];
              final branchNames = {
                for (final branch in branches) branch.id: branch.name,
              };

              return StreamBuilder<List<AppUser>>(
                stream: widget.authService.users.watchUsers(),
                builder: (context, userSnapshot) {
                  final employees = userSnapshot.data ?? const <AppUser>[];
                  final activeCount = employees
                      .where((item) => item.isActive)
                      .length;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _EmployeeManagementSummary(
                        totalEmployees: employees.length,
                        activeEmployees: activeCount,
                        onCreateEmployee:
                            branches.isEmpty || _isCreatingEmployee
                            ? null
                            : () => _openCreateEmployeeDialog(branches),
                      ),
                      const SizedBox(height: 18),
                      if (branches.isEmpty)
                        const _ManagementNotice(
                          message:
                              'No hay sucursales registradas. Crea una sucursal antes de agregar empleados.',
                        ),
                      if (employees.isEmpty)
                        const _ManagementNotice(
                          message: 'No hay empleados registrados.',
                        )
                      else
                        ...employees.map(
                          (employee) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _EmployeeCard(
                              employee: employee,
                              branchName:
                                  branchNames[employee.branchId] ??
                                  employee.branchId,
                              isUpdating: _updatingEmployeeId == employee.id,
                              onEdit: branches.isEmpty
                                  ? null
                                  : () => _openUpdateEmployeeDialog(
                                      employee,
                                      branches,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmployeeManagementSummary extends StatelessWidget {
  const _EmployeeManagementSummary({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.onCreateEmployee,
  });

  final int totalEmployees;
  final int activeEmployees;
  final VoidCallback? onCreateEmployee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Empleados registrados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Total',
                  value: '$totalEmployees',
                  color: AppPalette.blueSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryStat(
                  label: 'Activos',
                  value: '$activeEmployees',
                  color: AppPalette.mint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateEmployee,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nuevo empleado'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.branchName,
    required this.isUpdating,
    required this.onEdit,
  });

  final AppUser employee;
  final String branchName;
  final bool isUpdating;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final statusColor = employee.isActive ? AppPalette.mint : AppPalette.amber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.email,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: isUpdating ? null : onEdit,
                  icon: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_rounded),
                  label: const Text('Editar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EmployeePill(label: employee.role.displayName),
              _EmployeePill(label: branchName),
              _EmployeePill(
                label: employee.isActive ? 'Activo' : 'Inactivo',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Telefono: ${employee.phone.isEmpty ? 'Sin registro' : employee.phone}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _EmployeePill extends StatelessWidget {
  const _EmployeePill({required this.label, this.color = AppPalette.blueSoft});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ManagementNotice extends StatelessWidget {
  const _ManagementNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF102540),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppPalette.textMuted),
      ),
    );
  }
}
