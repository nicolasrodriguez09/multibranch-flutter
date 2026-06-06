import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../application/inventory_workflow_service.dart';
import '../domain/models.dart';
import 'product_search_page.dart';

class ProductSelectorField extends StatelessWidget {
  const ProductSelectorField({
    super.key,
    required this.service,
    required this.currentUser,
    required this.onChanged,
    this.initialFilters,
    this.selectedText,
    this.labelText = 'Producto',
    this.hintText = 'Toca para buscar o escanear',
    this.errorText,
    this.onClear,
  });

  final InventoryWorkflowService service;
  final AppUser currentUser;
  final ValueChanged<ProductSearchResult?> onChanged;
  final ProductSearchFilters? initialFilters;
  final String? selectedText;
  final String labelText;
  final String hintText;
  final String? errorText;
  final VoidCallback? onClear;

  Future<void> _openSearch(BuildContext context) async {
    final result = await Navigator.of(context).push<ProductSearchResult>(
      MaterialPageRoute<ProductSearchResult>(
        builder: (context) => ProductSearchPage(
          service: service,
          currentUser: currentUser,
          isSelectionMode: true,
          initialFilters: initialFilters,
        ),
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openSearch(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          errorText: errorText,
          suffixIcon: selectedText != null && onClear != null
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: onClear,
                )
              : const Icon(Icons.search_rounded),
        ),
        child: selectedText != null && selectedText!.isNotEmpty
            ? Text(
                selectedText!,
                style: const TextStyle(color: AppPalette.textPrimary),
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                hintText,
                style: const TextStyle(color: Colors.white54),
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
