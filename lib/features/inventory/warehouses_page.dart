/// Warehouses Page
///
/// Main inventory module screen. Summarizes warehouses, total items,
/// low-stock (reorder) alerts, and provides quick actions for transfers,
/// movements and stock counts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';

import 'inventory_providers.dart';
import 'inventory_repository.dart';
import 'stock_repository.dart';

/// Main warehouses & inventory page.
class WarehousesPage extends ConsumerWidget {
  const WarehousesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehousesStreamProvider);
    final balancesAsync = ref.watch(stockBalancesProvider(kAllWarehouses));
    final lowStockAsync = ref.watch(lowStockProvider(kAllWarehouses));

    final warehouses = warehousesAsync.value ?? <Warehouse>[];
    final balances = balancesAsync.value ?? <StockBalance>[];
    final lowCount = lowStockAsync.value?.length ?? 0;
    final totalQty = balances.fold<double>(0, (sum, b) => sum + b.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخازن'),
        actions: [
          IconButton(
            tooltip: 'التحويل بين المخازن',
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => context.go('/warehouses/transfer'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/warehouses/form'),
        icon: const Icon(Icons.add),
        label: const Text('مخزن جديد'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisExtent: 122,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: [
              StatCard(
                icon: Icons.warehouse_outlined,
                title: 'المخازن',
                value: warehouses.length.toString(),
                color: AppColors.info,
              ),
              StatCard(
                icon: Icons.inventory_2_outlined,
                title: 'إجمالي الأصناف',
                value: balances.length.toString(),
                color: AppColors.primary,
              ),
              StatCard(
                icon: Icons.warning_amber_outlined,
                title: 'أصناف منخفضة (حد إعادة الطلب)',
                value: lowCount.toString(),
                subtitle: lowCount > 0 ? 'تحتاج إعادة طلب' : 'مستقر',
                color: lowCount > 0 ? AppColors.error : AppColors.success,
                onTap: lowCount > 0
                    ? () => context.go('/warehouses/low-stock')
                    : null,
              ),
              StatCard(
                icon: Icons.all_inbox_outlined,
                title: 'إجمالي الكمية',
                value: totalQty.toStringAsFixed(0),
                color: AppColors.goldDark,
              ),
            ],
          ),
          const SizedBox(height: 16),

          SectionHeader(title: 'إجراءات سريعة'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('تحويل بين المخازن'),
                onPressed: () => context.go('/warehouses/transfer'),
              ),
              ActionChip(
                avatar: const Icon(Icons.trending_up, size: 18),
                label: const Text('حركة وارد / منصرف'),
                onPressed: () => context.go('/warehouses/movement'),
              ),
              ActionChip(
                avatar: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('الجرد'),
                onPressed: () => context.go('/warehouses/count'),
              ),
              ActionChip(
                avatar: const Icon(Icons.reorder, size: 18),
                label: const Text('حد إعادة الطلب'),
                onPressed: () => context.go('/warehouses/low-stock'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SectionHeader(
            title: 'المخازن',
            actionLabel: 'إضافة',
            onAction: () => context.go('/warehouses/form'),
          ),
          const SizedBox(height: 8),
          if (warehousesAsync.isLoading)
            const LoadingWidget(message: 'جاري تحميل المخازن...')
          else if (warehouses.isEmpty)
            EmptyState(
              icon: Icons.warehouse_outlined,
              title: 'لا توجد مخازن',
              subtitle: 'ابدأ بإضافة مخزن جديد لتتبّع مخزونك',
              actionLabel: 'إضافة مخزن',
              onAction: () => context.go('/warehouses/form'),
            )
          else
            ...warehouses.map((w) => _WarehouseTile(warehouse: w)),
        ],
      ),
    );
  }
}

/// A single warehouse card/tile.
class _WarehouseTile extends StatelessWidget {
  final Warehouse warehouse;

  const _WarehouseTile({required this.warehouse});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.warehouse, color: AppColors.primary),
        ),
        title: Text(
          warehouse.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('اضغط لعرض الأرصدة والحركة والجرد'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/warehouses/detail/${warehouse.id}'),
        onLongPress: () => context.go('/warehouses/form', extra: warehouse.id),
      ),
    );
  }
}
