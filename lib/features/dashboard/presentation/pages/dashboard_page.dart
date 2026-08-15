/// Dashboard Page
///
/// Main dashboard for the ERP system.
/// Displays today's sales, purchases, expenses, net profit,
/// customer/product/order counts, top products, low stock,
/// monthly revenue/profit charts, and recent invoices.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/dashboard_stats.dart';
import '../providers/dashboard_providers.dart';

/// Dashboard page widget.
///
/// Shows a comprehensive overview of the ERP system with:
/// - KPI stat cards (sales, purchases, expenses, profit)
/// - Count cards (customers, products, orders, sales reps)
/// - Monthly revenue and profit charts
/// - Top selling products list
/// - Low stock products list
/// - Recent invoices list
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Load stats on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardStatsProvider.notifier).loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(dashboardStatsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const LoadingWidget(message: 'جاري تحميل البيانات...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('حدث خطأ: $error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.read(dashboardStatsProvider.notifier).refresh();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardStatsProvider.notifier).refresh(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome header
                _buildWelcomeHeader(context),
                const SizedBox(height: 24),

                // KPI Stat Cards Row 1
                _buildKpiCards(context, stats),
                const SizedBox(height: 16),

                // Count Cards Row
                _buildCountCards(context, stats),
                const SizedBox(height: 24),

                // Charts Section
                _buildChartsSection(context, stats),
                const SizedBox(height: 24),

                // Top Products & Low Stock
                _buildProductsSection(context, stats),
                const SizedBox(height: 24),

                // Recent Invoices
                _buildRecentInvoices(context, stats),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the welcome header with date.
  Widget _buildWelcomeHeader(BuildContext context) {
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year}';
    final hour = now.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'صباح الخير';
    } else if (hour < 18) {
      greeting = 'مساء الخير';
    } else {
      greeting = 'مساء الخير';
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'مرحباً بك في نظام Marivio ERP',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.calendar_today, color: AppColors.gold, size: 28),
              const SizedBox(height: 8),
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Builds the KPI stat cards (sales, purchases, expenses, profit).
  Widget _buildKpiCards(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            StatCard(
              icon: Icons.trending_up,
              title: 'مبيعات اليوم',
              value: _formatCurrency(stats.todaySales),
              subtitle: 'اليوم',
              color: AppColors.success,
            ),
            StatCard(
              icon: Icons.shopping_cart,
              title: 'مشتريات اليوم',
              value: _formatCurrency(stats.todayPurchases),
              subtitle: 'اليوم',
              color: AppColors.info,
            ),
            StatCard(
              icon: Icons.money_off,
              title: 'مصروفات اليوم',
              value: _formatCurrency(stats.todayExpenses),
              subtitle: 'اليوم',
              color: AppColors.warning,
            ),
            StatCard(
              icon: Icons.account_balance_wallet,
              title: 'صافي الربح',
              value: _formatCurrency(stats.netProfit),
              subtitle: stats.netProfit >= 0 ? 'ربح' : 'خسارة',
              color: stats.netProfit >= 0
                  ? AppColors.success
                  : AppColors.error,
            ),
          ],
        );
      },
    );
  }

  /// Builds the count cards (customers, products, orders, sales reps).
  Widget _buildCountCards(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1.8,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildCountCard(
              context,
              icon: Icons.people,
              title: 'العملاء',
              value: stats.customerCount.toString(),
              color: AppColors.primary,
              onTap: () => context.go('/customers'),
            ),
            _buildCountCard(
              context,
              icon: Icons.inventory_2,
              title: 'المنتجات',
              value: stats.productCount.toString(),
              color: AppColors.primaryLight,
              onTap: () => context.go('/products'),
            ),
            _buildCountCard(
              context,
              icon: Icons.receipt_long,
              title: 'طلبات اليوم',
              value: stats.orderCount.toString(),
              color: AppColors.goldDark,
              onTap: () => context.go('/sales'),
            ),
            _buildCountCard(
              context,
              icon: Icons.badge,
              title: 'مندوبي المبيعات',
              value: stats.salesRepCount.toString(),
              color: AppColors.info,
            ),
          ],
        );
      },
    );
  }

  /// Builds a count card with icon and value.
  Widget _buildCountCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                    ),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1);
  }

  /// Builds the charts section with revenue and profit charts.
  Widget _buildChartsSection(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          // Side by side on desktop
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRevenueChart(context, stats)),
              const SizedBox(width: 16),
              Expanded(child: _buildProfitChart(context, stats)),
            ],
          );
        }
        // Stacked on mobile
        return Column(
          children: [
            _buildRevenueChart(context, stats),
            const SizedBox(height: 16),
            _buildProfitChart(context, stats),
          ],
        );
      },
    );
  }

  /// Builds the monthly revenue chart.
  Widget _buildRevenueChart(BuildContext context, DashboardStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'الإيرادات الشهرية',
              icon: Icons.bar_chart,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: stats.monthlyRevenue.isEmpty
                  ? const EmptyState(
                      icon: Icons.bar_chart,
                      title: 'لا توجد بيانات',
                    )
                  : _buildBarChart(stats.monthlyRevenue, AppColors.primary),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Builds the monthly profit chart.
  Widget _buildProfitChart(BuildContext context, DashboardStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'الأرباح الشهرية',
              icon: Icons.trending_up,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: stats.monthlyProfit.isEmpty
                  ? const EmptyState(
                      icon: Icons.trending_up,
                      title: 'لا توجد بيانات',
                    )
                  : _buildBarChart(stats.monthlyProfit, AppColors.gold),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Builds a bar chart from monthly data.
  Widget _buildBarChart(List<MonthlyData> data, Color color) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isEmpty
            ? 100
            : data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                _formatCurrency(data[groupIndex].value),
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].month,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.value,
                color: color,
                width: 22,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Builds the top products and low stock section.
  Widget _buildProductsSection(BuildContext context, DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopProducts(context, stats)),
              const SizedBox(width: 16),
              Expanded(child: _buildLowStock(context, stats)),
            ],
          );
        }
        return Column(
          children: [
            _buildTopProducts(context, stats),
            const SizedBox(height: 16),
            _buildLowStock(context, stats),
          ],
        );
      },
    );
  }

  /// Builds the top selling products list.
  Widget _buildTopProducts(BuildContext context, DashboardStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'المنتجات الأكثر مبيعاً',
              icon: Icons.star,
            ),
            const SizedBox(height: 16),
            if (stats.topProducts.isEmpty)
              const EmptyState(
                icon: Icons.star_border,
                title: 'لا توجد منتجات مبيعاً',
                subtitle: 'لم يتم تسجيل أي مبيعات بعد',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats.topProducts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final product = stats.topProducts[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.gold.withAlpha(26),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: AppColors.goldDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text('الكمية: ${product.totalQuantity}'),
                    trailing: Text(
                      _formatCurrency(product.totalRevenue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Builds the low stock products list.
  Widget _buildLowStock(BuildContext context, DashboardStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'منتجات مخزون منخفض',
              icon: Icons.warning,
            ),
            const SizedBox(height: 16),
            if (stats.lowStockProducts.isEmpty)
              const EmptyState(
                icon: Icons.check_circle,
                title: 'لا توجد منتجات منخفضة',
                subtitle: 'جميع المنتجات بمخزون كافٍ',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats.lowStockProducts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final product = stats.lowStockProducts[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.error,
                      child: Icon(Icons.warning, color: Colors.white, size: 20),
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      'المخزون: ${product.currentStock.toStringAsFixed(0)} / الحد الأدنى: ${product.minimumStock.toStringAsFixed(0)}',
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'منخفض',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Builds the recent invoices list.
  Widget _buildRecentInvoices(BuildContext context, DashboardStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'أحدث الفواتير',
              icon: Icons.receipt,
              actionLabel: 'عرض الكل',
              onAction: () => context.go('/sales'),
            ),
            const SizedBox(height: 16),
            if (stats.recentInvoices.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long,
                title: 'لا توجد فواتير',
                subtitle: 'لم يتم إنشاء أي فواتير بعد',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stats.recentInvoices.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final invoice = stats.recentInvoices[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(invoice.status).withAlpha(26),
                      child: Icon(
                        _getStatusIcon(invoice.status),
                        color: _getStatusColor(invoice.status),
                        size: 20,
                      ),
                    ),
                    title: Text(invoice.invoiceNumber),
                    subtitle: Text(invoice.customerName),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(invoice.grandTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getStatusText(invoice.status),
                          style: TextStyle(
                            color: _getStatusColor(invoice.status),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  /// Formats a currency value.
  String _formatCurrency(double value) {
    if (value == 0) return '0 ج.م';
    return '${value.toStringAsFixed(2)} ج.م';
  }

  /// Gets the status color for an invoice status.
  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.success;
      case 'partially_paid':
        return AppColors.warning;
      case 'unpaid':
        return AppColors.error;
      case 'cancelled':
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }

  /// Gets the status icon for an invoice status.
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'paid':
        return Icons.check_circle;
      case 'partially_paid':
        return Icons.pending;
      case 'unpaid':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  /// Gets the status text in Arabic for an invoice status.
  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'مدفوعة';
      case 'partially_paid':
        return 'مدفوعة جزئياً';
      case 'unpaid':
        return 'غير مدفوعة';
      case 'cancelled':
        return 'ملغاة';
      case 'draft':
        return 'مسودة';
      default:
        return status;
    }
  }
}