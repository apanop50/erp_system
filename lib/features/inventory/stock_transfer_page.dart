/// Stock Transfer Page
///
/// Transfers product quantities between two warehouses.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../products/presentation/providers/product_providers.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';
import 'stock_repository.dart';

class StockTransferPage extends ConsumerStatefulWidget {
  const StockTransferPage({super.key});

  @override
  ConsumerState<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends ConsumerState<StockTransferPage> {
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String? _fromWarehouseId;
  String? _toWarehouseId;
  String? _productId;
  bool _isSaving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_fromWarehouseId == null ||
        _toWarehouseId == null ||
        _productId == null) {
      return;
    }
    if (_fromWarehouseId == _toWarehouseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التحويل لنفس المخزن')),
      );
      return;
    }
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل كمية صحيحة أكبر من صفر')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final warehouses = ref.read(warehousesStreamProvider).value ?? [];
      final products = ref.read(productListProvider).value ?? [];
      final product = products.where((p) => p.id == _productId).firstOrNull;
      if (product == null) return;

      await ref
          .read(stockRepositoryProvider)
          .createTransfer(
            StockTransfer(
              id: const Uuid().v4(),
              fromWarehouseId: _fromWarehouseId!,
              fromWarehouseName: warehouses
                  .where((w) => w.id == _fromWarehouseId)
                  .firstOrNull
                  ?.name,
              toWarehouseId: _toWarehouseId!,
              toWarehouseName: warehouses
                  .where((w) => w.id == _toWarehouseId)
                  .firstOrNull
                  ?.name,
              items: [
                StockTransferItem(
                  productId: product.id,
                  productName: product.name,
                  unit: product.unit,
                  quantity: quantity,
                ),
              ],
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحويل بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = ref.watch(warehousesStreamProvider).value ?? [];
    final products = ref.watch(productListProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('تحويل بين المخازن')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _fromWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'من مخزن',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                  ),
                  items: warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _fromWarehouseId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _toWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'إلى مخزن',
                    prefixIcon: Icon(Icons.warehouse),
                  ),
                  items: warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _toWarehouseId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _productId,
                  decoration: const InputDecoration(
                    labelText: 'المنتج',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: products
                      .map(
                        (p) =>
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _productId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('تنفيذ التحويل'),
                  ),
                ),
              ],
            ),
    );
  }
}

extension _FirstOrNullTransfer<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
