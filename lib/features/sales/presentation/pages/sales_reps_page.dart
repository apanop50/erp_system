/// Sales Representatives Page
///
/// Manages sales representatives and shows each representative's total sales.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../products/domain/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Sales representatives page.
class SalesRepsPage extends ConsumerStatefulWidget {
  const SalesRepsPage({super.key});

  @override
  ConsumerState<SalesRepsPage> createState() => _SalesRepsPageState();
}

class _SalesRepsPageState extends ConsumerState<SalesRepsPage> {
  Future<void> _addRep() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final commissionController = TextEditingController(text: '0');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة مندوب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم المندوب'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'الهاتف (اختياري)'),
            ),
            TextField(
              controller: commissionController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'نسبة العمولة %'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final repo = ref.read(salesRepositoryProvider);
              await repo.createRepresentative(SalesRepresentative(
                id: '',
                name: name,
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
                commissionRate: double.tryParse(commissionController.text) ?? 0,
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  /// Computes the net profit (selling - purchase cost, minus discounts) for
  /// the given invoices, using each item's stored cost when available and
  /// falling back to the product's latest cost price.
  double _netProfit(List<SalesInvoice> invoices, Map<String, double> costByProduct) {
    var profit = 0.0;
    for (final inv in invoices) {
      var gross = 0.0;
      for (final item in inv.items) {
        final cost = item.costPrice > 0
            ? item.costPrice
            : (costByProduct[item.productId] ?? 0);
        gross += item.total - (cost * item.quantity);
      }
      profit += gross - inv.discount;
    }
    return profit;
  }

  @override
  Widget build(BuildContext context) {
    final repsAsync = ref.watch(representativesStreamProvider);
    final invoicesAsync = ref.watch(invoiceListProvider);
    final products = ref.watch(productListProvider).valueOrNull ?? const <Product>[];
    final costByProduct = <String, double>{
      for (final p in products) p.id: p.costPrice,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('المندوبون'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addRep),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: _addRep,
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
      body: repsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (reps) {
          final invoices = invoicesAsync.valueOrNull ?? const <SalesInvoice>[];
          if (reps.isEmpty) {
            return const EmptyState(
              icon: Icons.person_add_alt,
              title: 'لا يوجد مندوبون',
              subtitle: 'أضف مندوباً من زر إضافة',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reps.length,
            itemBuilder: (context, index) {
              final rep = reps[index];
              final repInvoices = invoices
                  .where((inv) => inv.salesRepId == rep.id && inv.status != InvoiceStatus.cancelled)
                  .toList();
              final total = repInvoices.fold(0.0, (sum, inv) => sum + inv.grandTotal);
              final profit = _netProfit(repInvoices, costByProduct);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withAlpha(26),
                    child: const Icon(Icons.person, color: AppColors.primary),
                  ),
                  title: Text(rep.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${repInvoices.length} فاتورة'
                    ' • الحساب الخاص (الربح): ${profit.toStringAsFixed(2)} ج.م'
                    '${rep.phone != null ? ' • ${rep.phone}' : ''}'
                    '${rep.commissionRate > 0 ? ' • عمولة ${rep.commissionRate}%' : ''}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${total.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Text('إجمالي المبيعات', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}