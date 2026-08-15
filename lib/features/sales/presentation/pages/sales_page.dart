/// Sales Invoices Page
///
/// Main sales module page. Lists all sales invoices with search/filter,
/// PDF preview/print, edit and delete actions, and invoice creation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../products/domain/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Sales invoices list page.
class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends ConsumerState<SalesPage> {
  InvoiceStatus? _statusFilter;

  Future<void> _printPriceList() async {
    await ref.read(productListProvider.notifier).loadProducts();
    final products = (ref.read(productListProvider).valueOrNull ?? const <Product>[])
        .where((p) => p.isActive)
        .toList();
    if (mounted && products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد منتجات لعرض قائمة الأسعار')),
      );
      return;
    }
    await ref.read(invoicePdfServiceProvider).printPriceListPdf(products);
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المبيعات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == '__price_list') {
                _printPriceList();
              } else {
                context.go(value);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: '/hotels', child: Text('الفنادق')),
              PopupMenuItem(value: '/sales-reps', child: Text('المندوبون')),
              PopupMenuItem(value: '__price_list', child: Text('قائمة الأسعار')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'فاتورة جديدة',
            onPressed: () => context.go('/sales/invoice-form'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: () => context.go('/sales/invoice-form'),
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
      body: Column(
        children: [
          // Status filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _filterChip('الكل', null),
                ...InvoiceStatus.values.map((s) => _filterChip(s.ar, s)),
              ],
            ),
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const LoadingWidget(message: 'جاري تحميل الفواتير...'),
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
                          ref.read(invoiceListProvider.notifier).loadInvoices(),
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (invoices) {
                final filtered = _statusFilter == null
                    ? invoices
                    : invoices.where((inv) => inv.status == _statusFilter).toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.receipt_long,
                    title: 'لا توجد فواتير',
                    subtitle: 'أنشئ أول فاتورة من زر إضافة',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(invoiceListProvider.notifier).loadInvoices(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _InvoiceCard(invoice: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, InvoiceStatus? status) {
    final selected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = status),
      ),
    );
  }
}
/// Card representing a single sales invoice.
class _InvoiceCard extends ConsumerWidget {
  final SalesInvoice invoice;

  const _InvoiceCard({required this.invoice});

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid:
        return AppColors.success;
      case InvoiceStatus.partiallyPaid:
        return AppColors.warning;
      case InvoiceStatus.cancelled:
      case InvoiceStatus.unpaid:
        return AppColors.error;
      case InvoiceStatus.draft:
        return AppColors.textSecondaryLight;
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الفاتورة'),
        content: Text('هل أنت متأكد من حذف فاتورة ${invoice.invoiceNumber}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final done = await ref
          .read(invoiceListProvider.notifier)
          .deleteInvoice(invoice.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(done ? 'تم الحذف' : 'فشل الحذف')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/sales/invoice-form', extra: invoice.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.customerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor(invoice.status).withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      invoice.status.ar,
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(invoice.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.receipt, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(_fmtDate(invoice.invoiceDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${invoice.grandTotal.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: AppColors.error),
                        tooltip: 'PDF',
                        onPressed: () => ref
                            .read(invoicePdfServiceProvider)
                            .printInvoicePdf(invoice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'مشاركة PDF',
                        onPressed: () => ref
                            .read(invoicePdfServiceProvider)
                            .shareInvoicePdf(invoice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        tooltip: 'حذف',
                        onPressed: () => _confirmDelete(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}