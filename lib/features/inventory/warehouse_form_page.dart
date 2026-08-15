/// Warehouse Form Page
///
/// Add/Edit form for a warehouse in the inventory module.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';

/// Form page for adding or editing a warehouse.
class WarehouseFormPage extends ConsumerStatefulWidget {
  final String? warehouseId;

  const WarehouseFormPage({super.key, this.warehouseId});

  @override
  ConsumerState<WarehouseFormPage> createState() => _WarehouseFormPageState();
}

class _WarehouseFormPageState extends ConsumerState<WarehouseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.warehouseId != null) {
      _loadName();
    }
  }

  Future<void> _loadName() async {
    final warehouses = ref.read(warehousesStreamProvider).value;
    if (warehouses == null) return;
    final match = warehouses
        .where((w) => w.id == widget.warehouseId)
        .firstOrNull;
    if (match != null) {
      _nameController.text = match.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(stockRepositoryProvider);
      final name = _nameController.text.trim();
      if (widget.warehouseId == null) {
        await repo.createWarehouse(
          Warehouse(id: const Uuid().v4(), name: name),
        );
      } else {
        await repo.updateWarehouse(
          Warehouse(id: widget.warehouseId!, name: name),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.warehouseId == null
                  ? 'تم إضافة المخزن بنجاح'
                  : 'تم تحديث المخزن بنجاح',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/warehouses');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحفظ: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.warehouseId == null ? 'إضافة مخزن جديد' : 'تعديل مخزن',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المخزن *',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم المخزن';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    widget.warehouseId == null
                        ? 'إضافة المخزن'
                        : 'تحديث المخزن',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
