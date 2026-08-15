/// Stock Count Page
///
/// Performs an inventory count for a warehouse and applies differences as
/// stock count adjustment movements.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';
import 'stock_repository.dart';

class StockCountPage extends ConsumerStatefulWidget {
  final String? warehouseId;

  const StockCountPage({super.key, this.warehouseId});

  @override
  ConsumerState<StockCountPage> createState() => _StockCountPageState();
}

class _StockCountPageState extends ConsumerState<StockCountPage> {
  final _notesController = TextEditingController();
  final Map<String, TextEditingController> _countControllers = {};
  String? _warehouseId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _warehouseId = widget.warehouseId;
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _countControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(StockBalance balance) {
    return _countControllers.putIfAbsent(
      balance.id,
      () => TextEditingController(text: balance.quantity.toStringAsFixed(0)),
    );
  }

  Future<void> _save(List<StockBalance> balances) async {
    if (_warehouseId == null || balances.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final warehouses = ref.read(warehousesStreamProvider).value ?? [];
      final warehouseName = warehouses
          .where((w) => w.id == _warehouseId)
          .firstOrNull
          ?.name;

      final items = balances.map((balance) {
        final countQty =
            double.tryParse(_controllerFor(balance).text) ?? balance.quantity;
        return StockCountItem(
          productId: balance.productId,
          productName: balance.productName,
          unit: balance.unit,
          systemQty: balance.quantity,
          countQty: countQty,
        );
      }).toList();

      await ref
          .read(stockRepositoryProvider)
          .createStockCount(
            StockCount(
              id: const Uuid().v4(),
              warehouseId: _warehouseId!,
              warehouseName: warehouseName,
              items: items,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            ),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الجرد وتطبيق الفروقات'),
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
    final balancesAsync = _warehouseId == null
        ? const AsyncValue<List<StockBalance>>.data([])
        : ref.watch(stockBalancesProvider(_warehouseId!));
    final balances = balancesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('الجرد')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _warehouseId,
                  decoration: const InputDecoration(
                    labelText: 'اختر المخزن',
                    prefixIcon: Icon(Icons.warehouse_outlined),
                  ),
                  items: warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _warehouseId = value),
                ),
                const SizedBox(height: 16),
                if (_warehouseId == null)
                  const EmptyState(
                    icon: Icons.warehouse_outlined,
                    title: 'اختر مخزن',
                    subtitle: 'اختر المخزن أولاً لإظهار أرصدته',
                  )
                else if (balancesAsync.isLoading)
                  const LoadingWidget(message: 'جاري تحميل الأرصدة...')
                else if (balances.isEmpty)
                  const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد أرصدة',
                    subtitle: 'لا يوجد مخزون مسجل لهذا المخزن بعد',
                  )
                else ...[
                  const Text(
                    'أدخل الكمية الفعلية لكل صنف. سيتم تطبيق الفرق تلقائيًا.',
                    style: TextStyle(color: AppColors.info),
                  ),
                  const SizedBox(height: 12),
                  ...balances.map((balance) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    balance.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'النظام: ${balance.quantity.toStringAsFixed(0)} ${balance.unit}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _controllerFor(balance),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'فعلي',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الجرد',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _save(balances),
                      icon: const Icon(Icons.fact_check_outlined),
                      label: const Text('حفظ الجرد وتطبيق الفروقات'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

extension _FirstOrNullCount<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
