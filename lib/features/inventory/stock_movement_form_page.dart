/// Stock Movement Form Page
///
/// Records an inbound (وارد) or outbound (منصرف) stock movement for a product
/// in a warehouse.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

import '../products/presentation/providers/product_providers.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';
import 'stock_repository.dart';

/// Form to add a stock movement.
class StockMovementFormPage extends ConsumerStatefulWidget {
  final String? warehouseId;

  const StockMovementFormPage({super.key, this.warehouseId});

  @override
  ConsumerState<StockMovementFormPage> createState() =>
      _StockMovementFormPageState();
}

class _StockMovementFormPageState extends ConsumerState<StockMovementFormPage> {
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;
  String? _warehouseId;
  String? _productId;
  MovementType _type = MovementType.inbound;

  @override
  void initState() {
    super.initState();
    _warehouseId = widget.warehouseId;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_warehouseId == null || _productId == null) return;
    setState(() => _isSaving = true);
    try {
      final warehouses = ref.read(warehousesStreamProvider).value ?? [];
      final whName = warehouses
          .where((w) => w.id == _warehouseId)
          .firstOrNull
          ?.name;
      final products = ref.read(productListProvider).value ?? [];
      final product = products.where((p) => p.id == _productId).firstOrNull;
      final qty = double.tryParse(_quantityController.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل كمية صحيحة أكبر من صفر')),
        );
        return;
      }
      if (product == null) return;
      await ref
          .read(stockRepositoryProvider)
          .applyMovement(
            warehouseId: _warehouseId!,
            warehouseName: whName,
            productId: product.id,
            productName: product.name,
            unit: product.unit,
            delta: _type == MovementType.inbound ? qty : -qty,
            type: _type,
            reference: _type == MovementType.inbound
                ? 'إدخال يدوي'
                : 'إخراج يدوي',
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == MovementType.inbound
                  ? 'تم تسجيل الحركة الواردة'
                  : 'تم تسجيل الحركة المنصرفة',
            ),
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
      appBar: AppBar(title: const Text('حركة وارد / منصرف')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _warehouseId,
                  decoration: const InputDecoration(
                    labelText: 'المخزن *',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                  ),
                  items: warehouses
                      .map(
                        (w) => DropdownMenuItem<String>(
                          value: w.id,
                          child: Text(w.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _warehouseId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MovementType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'نوع الحركة',
                    prefixIcon: Icon(Icons.swap_vert),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MovementType.inbound,
                      child: Text('وارد'),
                    ),
                    DropdownMenuItem(
                      value: MovementType.outbound,
                      child: Text('منصرف'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? MovementType.inbound),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _productId,
                  decoration: const InputDecoration(
                    labelText: 'المنتج *',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  items: products
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _productId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الكمية *',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: (_warehouseId == null || _productId == null)
                        ? null
                        : _handleSave,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _type == MovementType.inbound
                          ? 'تسجيل وارد'
                          : 'تسجيل منصرف',
                    ),
                  ),
                ),
                if (warehouses.isEmpty || products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'تأكد من وجود مخزن ومنتجات أولاً.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
              ],
            ),
    );
  }
}

extension _FirstOrNullMovement<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
