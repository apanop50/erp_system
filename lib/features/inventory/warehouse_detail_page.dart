/// Warehouse Detail Page
///
/// Shows a warehouse's stock balances, movement history, allows adding
/// inbound/outbound movements, running a stock count, editing the reorder
/// point (minimum stock), and deleting the warehouse.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';
import 'stock_repository.dart';

/// Detail page for a single warehouse.
class WarehouseDetailPage extends ConsumerWidget {
  final String warehouseId;

  const WarehouseDetailPage({super.key, required this.warehouseId});

  String? _warehouseName(WidgetRef ref) {
    return ref
        .watch(warehousesStreamProvider)
        .value
        ?.where((w) => w.id == warehouseId)
        .firstOrNull
        ?.name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _warehouseName(ref) ?? 'المخزن';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          actions: [
            IconButton(
              tooltip: 'حركة وارد / منصرف',
              icon: const Icon(Icons.trending_up),
              onPressed: () =>
                  context.go('/warehouses/movement', extra: warehouseId),
            ),
            IconButton(
              tooltip: 'جرد',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () =>
                  context.go('/warehouses/count', extra: warehouseId),
            ),
            IconButton(
              tooltip: 'حذف المخزن',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'الأرصدة'),
              Tab(icon: Icon(Icons.history), text: 'السجل'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BalancesTab(warehouseId: warehouseId),
            _MovementsTab(warehouseId: warehouseId),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المخزن'),
        content: const Text(
          'هل أنت متأكد من حذف هذا المخزن؟ ستبقى السجلات محفوظة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(stockRepositoryProvider).deleteWarehouse(warehouseId);
    if (context.mounted) context.go('/warehouses');
  }
}

/// Balances tab for a warehouse.
class _BalancesTab extends ConsumerWidget {
  final String warehouseId;
  const _BalancesTab({required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(stockBalancesProvider(warehouseId));
    return balancesAsync.when(
      loading: () => const LoadingWidget(message: 'جاري تحميل الأرصدة...'),
      error: (e, st) => Center(child: Text('خطأ: $e')),
      data: (balances) => balances.isEmpty
          ? const EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'لا توجد أرصدة',
              subtitle: 'أضِف حركة وارد أو نفّذ جردًا لبدء تسجيل المخزون',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: balances.length,
              itemBuilder: (context, index) {
                final b = balances[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      b.isLow ? Icons.warning_amber : Icons.inventory_2,
                      color: b.isLow ? AppColors.error : AppColors.primary,
                    ),
                    title: Text(
                      b.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'الحد الأدنى: ${b.minStock.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: b.isLow ? AppColors.error : Colors.grey[600],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${b.quantity.toStringAsFixed(0)} ${b.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: b.isLow
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                        if (b.isLow)
                          Text(
                            'تحتاج إعادة',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _editMinStock(context, ref, b),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _editMinStock(
    BuildContext context,
    WidgetRef ref,
    StockBalance balance,
  ) async {
    final controller = TextEditingController(
      text: balance.minStock.toStringAsFixed(0),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حد إعادة الطلب'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الحد الأدنى للمخزون'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text) ?? 0),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref
        .read(stockRepositoryProvider)
        .updateMinStock(
          warehouseId: balance.warehouseId,
          productId: balance.productId,
          minStock: result,
        );
  }
}

/// Movements tab for a warehouse.
class _MovementsTab extends ConsumerWidget {
  final String warehouseId;
  const _MovementsTab({required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(stockMovementsProvider(warehouseId));
    return movementsAsync.when(
      loading: () => const LoadingWidget(message: 'جاري تحميل الحركة...'),
      error: (e, st) => Center(child: Text('خطأ: $e')),
      data: (movements) => movements.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'لا توجد حركة',
              subtitle: 'سجّل حركة وارد أو منصرف لعرضها هنا',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: movements.length,
              itemBuilder: (context, index) {
                final m = movements[index];
                final isIn =
                    m.type == MovementType.inbound ||
                    m.type == MovementType.transferIn;
                final isOut =
                    m.type == MovementType.outbound ||
                    m.type == MovementType.transferOut;
                final Color color;
                switch (m.type) {
                  case MovementType.inbound:
                    color = AppColors.success;
                    break;
                  case MovementType.outbound:
                    color = AppColors.error;
                    break;
                  case MovementType.transferIn:
                    color = AppColors.info;
                    break;
                  case MovementType.transferOut:
                    color = AppColors.warning;
                    break;
                  case MovementType.adjustment:
                  case MovementType.count:
                    color = AppColors.primary;
                    break;
                }
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withAlpha(26),
                      child: Icon(
                        isIn
                            ? Icons.arrow_downward
                            : isOut
                            ? Icons.arrow_upward
                            : Icons.arrow_right_alt,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(m.productName),
                    subtitle: Text(
                      '${m.type.ar} · ${m.quantity.toStringAsFixed(0)} ${m.unit}'
                      '${m.createdAt != null ? ' · ${DateFormat("yyyy-MM-dd HH:mm").format(m.createdAt!)}' : ''}',
                    ),
                    trailing: Text(
                      m.quantity.toStringAsFixed(0),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Convenience accessor for the first matching element.
extension _FirstOrNullTwo<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
