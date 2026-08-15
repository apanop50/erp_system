/// Purchases Page
///
/// Lists purchase invoices from suppliers and allows creating a new purchase
/// invoice (which updates product stock and cost prices).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Purchases list page.
class PurchasesPage extends ConsumerWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchasesAsync = ref.watch(purchaseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المشتريات')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: () => context.go('/purchases/form'),
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
      body: purchasesAsync.when(
        loading: () => const LoadingWidget(message: 'جاري تحميل المشتريات...'),
        error: (e, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('حدث خطأ: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(purchaseListProvider.notifier).loadPurchases(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (purchases) {
          if (purchases.isEmpty) {
            return const EmptyState(
              icon: Icons.shopping_cart,
              title: 'لا توجد مشتريات',
              subtitle: 'أضف عمليات الشراء من مصادرك',
            );
          }
          final total = purchases.fold(0.0, (s, p) => s + p.grandTotal);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                color: AppColors.info.withAlpha(26),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('إجمالي المشتريات',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${total.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...purchases.map(
                (p) => _PurchaseCard(
                  purchase: p,
                  onDelete: () async {
                    await ref
                        .read(purchaseListProvider.notifier)
                        .deletePurchase(p.id);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final PurchaseInvoice purchase;
  final VoidCallback onDelete;

  const _PurchaseCard({required this.purchase, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(26),
          child: const Icon(Icons.local_shipping, color: AppColors.primary),
        ),
        title: Text(purchase.supplierName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${purchase.invoiceNumber} • ${DateFormat('dd/MM/yyyy').format(purchase.invoiceDate)} • ${purchase.items.length} صنف',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${purchase.grandTotal.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                Text(
                  purchase.status,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}