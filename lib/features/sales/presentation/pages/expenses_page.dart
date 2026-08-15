import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Expenses list page.
class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.miscellaneous;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _show(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _addExpense() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _show('أدخل مبلغاً صحيحاً');
      return;
    }
    final id = await ref.read(expenseListProvider.notifier).createExpense(
          Expense(
            id: '',
            category: _category,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            amount: amount,
            expenseDate: DateTime.now(),
          ),
        );
    if (id != null) {
      _amountController.clear();
      _descController.clear();
      setState(() => _category = ExpenseCategory.miscellaneous);
      _show('تمت إضافة المصروف');
    } else {
      _show('فشل الإضافة');
    }
  }

  Future<void> _deleteExpense(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: Text('حذف مصروف «${e.description ?? e.category.ar}»؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expenseListProvider.notifier).deleteExpense(e.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المصروفات')),
      body: Column(
        children: [
          _addCard(),
          Expanded(
            child: expensesAsync.when(
              loading: () => const LoadingWidget(),
              error: (e, st) => Center(child: Text('خطأ: $e')),
              data: (expenses) => _list(expenses),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الفئة',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: ExpenseCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.ar)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? ExpenseCategory.miscellaneous),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.add),
                  tooltip: 'إضافة',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return const EmptyState(icon: Icons.money_off, title: 'لا توجد مصروفات');
    }
    final total = expenses.fold(0.0, (s, e) => s + e.amount);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: AppColors.error.withAlpha(26),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي المصروفات', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${total.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...expenses.map((e) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(26),
                  child: const Icon(Icons.payments, color: AppColors.primary, size: 20),
                ),
                title: Text(e.description ?? e.category.ar),
                subtitle: Text(
                  '${e.category.ar} • ${DateFormat('dd/MM/yyyy').format(e.expenseDate)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${e.amount.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: () => _deleteExpense(e),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}