/// Reports Page
///
/// Financial & sales performance reports: profits, today's revenue/purchases/
/// expenses, and top-selling (best-selling) products.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../dashboard/domain/dashboard_stats.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';

/// Reports page.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardStatsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const LoadingWidget(message: 'جاري حساب التقارير...'),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (stats) => _buildBody(stats),
      ),
    );
  }

  Widget _buildBody(DashboardStats stats) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Profit overview
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.attach_money,
                title: 'مبيعات اليوم',
                value: _money(stats.todaySales),
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                icon: Icons.trending_up,
                title: 'صافي الربح',
                value: _money(stats.netProfit),
                color: stats.netProfit >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.shopping_cart,
                title: 'مشتريات اليوم',
                value: _money(stats.todayPurchases),
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                icon: Icons.money_off,
                title: 'مصروفات اليوم',
                value: _money(stats.todayExpenses),
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Best sellers
        const SectionHeader(title: 'الأكثر مبيعاً', icon: Icons.local_fire_department),
        const SizedBox(height: 8),
        if (stats.topProducts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد بيانات مبيعات بعد'),
            ),
          )
        else
          ...stats.topProducts.asMap().entries.map((entry) =>
              _TopProductTile(index: entry.key + 1, product: entry.value)),

        const SizedBox(height: 16),

        // Overview counts
        const SectionHeader(title: 'نظرة عامة', icon: Icons.info_outline),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _infoRow('عدد العملاء', '${stats.customerCount}'),
              const Divider(height: 1),
              _infoRow('عدد المنتجات', '${stats.productCount}'),
              const Divider(height: 1),
              _infoRow('عدد الفواتير', '${stats.orderCount}'),
              const Divider(height: 1),
              _infoRow('عدد المندوبين', '${stats.salesRepCount}'),
            ],
          ),
        ),
      ],
    );
  }

  String _money(double v) => '${v.toStringAsFixed(2)} ج.م';

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TopProductTile extends StatelessWidget {
  final int index;
  final TopProduct product;

  const _TopProductTile({required this.index, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.gold.withAlpha(51),
          child: Text('$index', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(product.name),
        subtitle: Text('الكمية المباعة: ${product.totalQuantity}'),
        trailing: Text(
          '${product.totalRevenue.toStringAsFixed(2)} ج.م',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
        ),
      ),
    );
  }
}