/// Customer Detail Page
///
/// Shows detailed information about a customer including:
/// personal info, account statement, invoices, payments, and statistics.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../sales/presentation/providers/sales_providers.dart';
import '../../../sales/domain/sales_model.dart';
import '../providers/customer_providers.dart';
import '../../domain/customer_model.dart';

/// Customer detail page widget.
class CustomerDetailPage extends ConsumerWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerStreamProvider(customerId));
    final paymentsAsync = ref.watch(customerPaymentsStreamProvider(customerId));
    final invoicesAsync = ref.watch(customerInvoicesStreamProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العميل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/customers/form', extra: customerId),
          ),
        ],
      ),
      body: customerAsync.when(
        loading: () => const LoadingWidget(message: 'جاري التحميل...'),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('خطأ: $error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(customerStreamProvider(customerId)),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (customer) {
          if (customer == null) {
            return const EmptyState(
              icon: Icons.person_off,
              title: 'العميل غير موجود',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary.withAlpha(26),
                          child: const Icon(Icons.person, size: 36, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (customer.companyName != null)
                                Text(customer.companyName!),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withAlpha(26),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  customer.customerType.ar,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.goldDark,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Account balance card
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'الرصيد الحالي',
                        '${customer.accountBalance.toStringAsFixed(2)} ج.م',
                        customer.accountBalance > 0 ? AppColors.error : AppColors.success,
                        Icons.account_balance_wallet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                        'حد الائتمان',
                        '${customer.creditLimit.toStringAsFixed(2)} ج.م',
                        AppColors.info,
                        Icons.credit_card,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Contact info
                const SectionHeader(title: 'معلومات الاتصال', icon: Icons.contact_phone),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (customer.phone != null)
                          _buildInfoRow(Icons.phone, 'الهاتف', customer.phone!),
                        if (customer.whatsapp != null)
                          _buildInfoRow(Icons.chat, 'واتساب', customer.whatsapp!),
                        if (customer.email != null)
                          _buildInfoRow(Icons.email, 'البريد', customer.email!),
                        if (customer.address != null)
                          _buildInfoRow(Icons.location_on, 'العنوان', customer.address!),
                        if (customer.city != null)
                          _buildInfoRow(Icons.location_city, 'المدينة', customer.city!),
                        if (customer.taxNumber != null)
                          _buildInfoRow(Icons.receipt, 'الرقم الضريبي', customer.taxNumber!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Payments history
                const SectionHeader(title: 'سجل المدفوعات', icon: Icons.payments),
                const SizedBox(height: 12),
                paymentsAsync.when(
                  loading: () => const LoadingWidget(),
                  error: (error, stack) => Text('خطأ: $error'),
                  data: (payments) {
                    if (payments.isEmpty) {
                      return const EmptyState(
                        icon: Icons.payments,
                        title: 'لا توجد مدفوعات',
                      );
                    }
                    return Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.payment, size: 20),
                            ),
                            title: Text('${payment.amount.toStringAsFixed(2)} ج.م'),
                            subtitle: Text(
                              '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                payment.paymentMethod,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Invoices
                const SectionHeader(title: 'الفواتير', icon: Icons.receipt_long),
                const SizedBox(height: 12),
                invoicesAsync.when(
                  loading: () => const LoadingWidget(),
                  error: (error, stack) => Text('خطأ: $error'),
                  data: (invoices) {
                    if (invoices.isEmpty) {
                      return const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'لا توجد فواتير',
                      );
                    }
                    final total = invoices.fold(0.0, (s, inv) => s + inv.grandTotal);
                    return Column(
                      children: [
                        Card(
                          color: AppColors.primary.withAlpha(26),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('إجمالي الفواتير', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  '${total.toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...invoices
                            .take(20)
                            .map((inv) => Card(
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  child: ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.receipt, color: AppColors.primary),
                                    title: Text('${inv.invoiceNumber} — ${inv.customerName}'),
                                    subtitle: Text(
                                      '${inv.invoiceDate.day}/${inv.invoiceDate.month}/${inv.invoiceDate.year} • ${inv.status.ar}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${inv.grandTotal.toStringAsFixed(2)} ج.م',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: AppColors.error),
                                          onPressed: () => ref
                                              .read(invoicePdfServiceProvider)
                                              .printInvoicePdf(inv),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Notes
                if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                  const SectionHeader(title: 'ملاحظات', icon: Icons.notes),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(customer.notes!),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
