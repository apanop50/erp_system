/// Customers Page
///
/// Main customers list page for the ERP system.
/// Displays customers in a list with search, filter by type, and CRUD actions.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/customer_providers.dart';
import '../../domain/customer_model.dart';

/// Customers list page widget.
class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  CustomerType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              hintText: 'بحث بالاسم أو الهاتف...',
              onChanged: (value) {
                if (value.isNotEmpty) {
                  ref.read(customerListProvider.notifier).searchCustomers(value);
                } else {
                  ref.read(customerListProvider.notifier).loadCustomers();
                }
              },
            ),
          ),
          // Customer type filter chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('الكل', null),
                ...CustomerType.values.map(
                  (type) => _buildFilterChip(type.ar, type),
                ),
              ],
            ),
          ),
          // Customers list
          Expanded(
            child: customersAsync.when(
              loading: () => const LoadingWidget(message: 'جاري تحميل العملاء...'),
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
                        ref.read(customerListProvider.notifier).loadCustomers();
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (customers) {
                if (customers.isEmpty) {
                  return EmptyState(
                    icon: Icons.people,
                    title: 'لا يوجد عملاء',
                    subtitle: 'لم يتم إضافة أي عملاء بعد',
                    actionLabel: 'إضافة عميل جديد',
                    onAction: () => context.go('/customers/form'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _buildCustomerCard(context, customer, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/customers/form'),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds a filter chip for customer type.
  Widget _buildFilterChip(String label, CustomerType? type) {
    final isSelected = _selectedType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedType = selected ? type : null);
          ref.read(customerListProvider.notifier).loadCustomers(
                customerType: _selectedType,
              );
        },
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.primary,
        ),
      ),
    );
  }

  /// Builds a customer card.
  Widget _buildCustomerCard(BuildContext context, Customer customer, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.go('/customers/detail/${customer.id}'),
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(customer.customerType).withAlpha(26),
          child: Icon(
            _getTypeIcon(customer.customerType),
            color: _getTypeColor(customer.customerType),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customer.companyName != null) Text(customer.companyName!),
            if (customer.phone != null) Text('هاتف: ${customer.phone}'),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getTypeColor(customer.customerType).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    customer.customerType.ar,
                    style: TextStyle(
                      fontSize: 11,
                      color: _getTypeColor(customer.customerType),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'الرصيد: ${customer.accountBalance.toStringAsFixed(2)} ج.م',
                  style: TextStyle(
                    fontSize: 12,
                    color: customer.accountBalance > 0
                        ? AppColors.error
                        : AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1);
  }

  /// Gets the color for a customer type.
  Color _getTypeColor(CustomerType type) {
    switch (type) {
      case CustomerType.normal:
        return AppColors.primary;
      case CustomerType.hotel:
        return AppColors.goldDark;
      case CustomerType.restaurant:
        return AppColors.warning;
      case CustomerType.supermarket:
        return AppColors.info;
      case CustomerType.factory:
        return AppColors.success;
      case CustomerType.Supplier:
        return AppColors.darkNavy;
    }
  }

  /// Gets the icon for a customer type.
  IconData _getTypeIcon(CustomerType type) {
    switch (type) {
      case CustomerType.normal:
        return Icons.person;
      case CustomerType.hotel:
        return Icons.hotel;
      case CustomerType.restaurant:
        return Icons.restaurant;
      case CustomerType.supermarket:
        return Icons.store;
      case CustomerType.factory:
        return Icons.factory;
      case CustomerType.Supplier:
        return Icons.support;

    }
  }
}
