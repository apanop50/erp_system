/// Finance Page (الحسابات)
///
/// Shows رأس المال (capital), الأرباح (profit), إجمالي المشتريات/المبيعات,
/// and the partners (الشركاء) with their balances and add/withdraw money.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../inventory/inventory_repository.dart' show Tenant;
import '../../domain/finance_model.dart';
import '../providers/finance_providers.dart';

/// Finance main page.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financeSummaryProvider);
    final partnersAsync = ref.watch(partnersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الحسابات')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeSummaryProvider);
          ref.invalidate(partnersListProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            summary.when(
              loading: () => const LoadingWidget(),
              error: (e, st) => Center(child: Text('خطأ: $e')),
              data: (s) => _buildSummary(s),
            ),
            const SizedBox(height: 16),
            SectionHeader(
              title: 'الشركاء',
              icon: Icons.group,
              actionLabel: 'إضافة شريك',
              onAction: () => _partnerDialog(context, ref),
            ),
            const SizedBox(height: 8),
            partnersAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, st) => Center(child: Text('خطأ: $e')),
              data: (partners) => partners.isEmpty
                  ? EmptyState(
                      icon: Icons.group,
                      title: 'لا يوجد شركاء',
                      subtitle: 'أضف شريكاً',
                      actionLabel: 'إضافة شريك',
                      onAction: () => _partnerDialog(context, ref),
                    )
                  : Column(
                      children: partners
                          .map(
                            (p) => _PartnerTile(
                              partner: p,
                              onAddMoney: () =>
                                  _moneyDialog(context, ref, p, add: true),
                              onWithdraw: () =>
                                  _moneyDialog(context, ref, p, add: false),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(FinanceSummary s) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.account_balance,
                title: 'رأس المال',
                value: _money(s.capital),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                icon: Icons.trending_up,
                title: 'الأرباح',
                value: _money(s.profit),
                color: AppColors.success,
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
                title: 'المشتريات',
                value: _money(s.purchases),
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatCard(
                icon: Icons.point_of_sale,
                title: 'المبيعات',
                value: _money(s.sales),
                color: AppColors.goldDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          color: AppColors.warning.withAlpha(26),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'رصيد الشركاء',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _money(s.partnerBalance),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _moneyDialog(
    BuildContext context,
    WidgetRef ref,
    Tenant partner, {
    required bool add,
  }) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          add ? 'إيداع لـ ${partner.name}' : 'سحب من ${partner.name}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) {
                Navigator.pop(ctx);
                return;
              }
              final repo = ref.read(financeRepositoryProvider);
              if (add) {
                await repo.addPartnerMoney(
                  partnerId: partner.id,
                  amount: amount,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                );
              } else {
                await repo.withdrawPartnerMoney(
                  partnerId: partner.id,
                  amount: amount,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                );
              }
              ref.invalidate(financeSummaryProvider);
              ref.invalidate(partnerTransactionsProvider(partner.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _partnerDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final capitalController = TextEditingController(text: '0');
    final percentageController = TextEditingController(text: '0');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة شريك'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الشريك *',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: capitalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'رأس المال الافتتاحي',
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: percentageController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'نسبة الشراكة %',
                  prefixIcon: Icon(Icons.percent),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref
                  .read(financeRepositoryProvider)
                  .createPartner(
                    name: name,
                    capital: double.tryParse(capitalController.text) ?? 0,
                    percentage: double.tryParse(percentageController.text) ?? 0,
                  );
              ref.invalidate(partnersListProvider);
              ref.invalidate(financeSummaryProvider);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    nameController.dispose();
    capitalController.dispose();
    percentageController.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إضافة الشريك وتسجيل رأس المال'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  String _money(double v) => '${v.toStringAsFixed(2)} ج.م';
}

class _PartnerTile extends ConsumerWidget {
  final Tenant partner;
  final VoidCallback onAddMoney;
  final VoidCallback onWithdraw;

  const _PartnerTile({
    required this.partner,
    required this.onAddMoney,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(partnerTransactionsProvider(partner.id));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.gold.withAlpha(51),
            child: const Icon(Icons.person, color: AppColors.primary),
          ),
          title: Text(
            partner.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'رأس المال: ${partner.capital.toStringAsFixed(2)} ج.م'
            '${partner.percentage > 0 ? ' | النسبة: ${partner.percentage.toStringAsFixed(1)}%' : ''}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.success),
                tooltip: 'إيداع',
                onPressed: onAddMoney,
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle, color: AppColors.error),
                tooltip: 'سحب',
                onPressed: onWithdraw,
              ),
            ],
          ),
          children: [
            txnsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('خطأ في تحميل الحركة: $e'),
              ),
              data: (txns) {
                final balance = txns.fold<double>(
                  0,
                  (sum, t) => sum + (t.type == 'add' ? t.amount : -t.amount),
                );
                if (txns.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('لا توجد حركة أموال لهذا الشريك'),
                  );
                }
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'رصيد الشريك الحالي',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${balance.toStringAsFixed(2)} ج.م',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...txns.take(8).map((txn) {
                      final isAdd = txn.type == 'add';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isAdd ? Icons.south_west : Icons.north_east,
                          color: isAdd ? AppColors.success : AppColors.error,
                        ),
                        title: Text(isAdd ? 'إيداع شريك' : 'سحب شريك'),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd HH:mm').format(txn.date)}'
                          '${txn.notes == null ? '' : ' | ${txn.notes}'}',
                        ),
                        trailing: Text(
                          '${isAdd ? '+' : '-'}${txn.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isAdd ? AppColors.success : AppColors.error,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
