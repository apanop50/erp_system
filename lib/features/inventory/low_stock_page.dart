/// Low Stock Page
///
/// Lists balances at or below their reorder point.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import 'inventory_providers.dart';

class LowStockPage extends ConsumerWidget {
  const LowStockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lowStockProvider(kAllWarehouses));
    return Scaffold(
      appBar: AppBar(title: const Text('حد إعادة الطلب')),
      body: async.when(
        loading: () =>
            const LoadingWidget(message: 'جاري تحميل الأصناف المنخفضة...'),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'المخزون مستقر',
                subtitle: 'لا توجد أصناف وصلت لحد إعادة الطلب',
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final b = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: AppColors.error,
                      ),
                      title: Text(b.productName),
                      subtitle: Text(b.warehouseName ?? b.warehouseId),
                      trailing: Text(
                        '${b.quantity.toStringAsFixed(0)} / ${b.minStock.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
