/// Purchase Invoice Form Page
///
/// Create a purchase invoice from a supplier. The user picks a supplier and
/// adds line items (product + quantity + purchase price). On save the invoice
/// is persisted (locally first, then Firestore) and each purchased product's
/// stock and cost (last purchase price) are updated so profits can be computed
/// from purchase vs. sale prices.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../products/domain/product_model.dart' show Product, Supplier;
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Purchase invoice form page.
class PurchaseInvoiceFormPage extends ConsumerStatefulWidget {
  const PurchaseInvoiceFormPage({super.key});

  @override
  ConsumerState<PurchaseInvoiceFormPage> createState() =>
      _PurchaseInvoiceFormPageState();
}

class _PurchaseInvoiceFormPageState
    extends ConsumerState<PurchaseInvoiceFormPage> {
  final _notesController = TextEditingController();
  Supplier? _supplier;
  final List<_PLineItem> _items = [];
  double _discount = 0;
  double _taxAmount = 0;
  double _paidAmount = 0;
  bool _loading = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.quantity * item.unitPrice);
  double get _grandTotal => _subtotal - _discount + _taxAmount;

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final productsAsync = ref.watch(productListProvider);
    final suppliers = suppliersAsync.valueOrNull ?? [];
    final products = productsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة شراء جديدة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<Supplier>(
                  initialValue: _supplier,
                  decoration: const InputDecoration(
                    labelText: 'المورد',
                    prefixIcon: Icon(Icons.local_shipping),
                  ),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _supplier = value),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _addSupplierDialog,
                  icon: const Icon(Icons.add_business),
                  label: const Text('مورد جديد'),
                ),
              ),
            ],
          ),
          if (suppliers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'لا يوجد موردين. اضغط "مورد جديد" لإضافة أول مورد.',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: products.isEmpty ? null : () => _addItemModal(products),
            icon: const Icon(Icons.add),
            label: const Text('إضافة صنف'),
          ),
          const SizedBox(height: 8),

          if (_items.isEmpty)
            const EmptyState(
              icon: Icons.shopping_cart,
              title: 'لا توجد أصناف',
              subtitle: 'أضف أصنافاً من قائمة المنتجات',
            )
          else
            ..._items.map(
              (item) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () =>
                                setState(() => _items.remove(item)),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _NumberField(
                              label: 'الكمية',
                              initial: item.quantity,
                              onChanged: (v) => item.quantity = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _NumberField(
                              label: 'سعر الشراء',
                              initial: item.unitPrice,
                              onChanged: (v) => item.unitPrice = v,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              prefixIcon: Icon(Icons.notes),
            ),
          ),
          const SizedBox(height: 12),
          _MoneyField(
            label: 'الخصم',
            value: _discount,
            onChanged: (v) => setState(() => _discount = v),
          ),
          const SizedBox(height: 8),
          _MoneyField(
            label: 'الضرائب',
            value: _taxAmount,
            onChanged: (v) => setState(() => _taxAmount = v),
          ),
          const SizedBox(height: 8),
          _MoneyField(
            label: 'المدفوع',
            value: _paidAmount,
            onChanged: (v) => setState(() => _paidAmount = v),
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.info.withAlpha(26),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الإجمالي',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_grandTotal.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('حفظ فاتورة الشراء'),
            ),
          ),
        ],
      ),
    );
  }

  void _addItemModal(List<Product> products) {
    showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddItemSheet(products: products),
    ).then((product) {
      if (product != null && mounted) {
        setState(() {
          for (final existing in _items) {
            if (existing.productId == product.id) {
              existing.quantity += 1;
              return;
            }
          }
          _items.add(
            _PLineItem(
              productId: product.id,
              name: product.name,
              quantity: 1,
              unitPrice: product.costPrice,
            ),
          );
        });
      }
    });
  }

  Future<void> _addSupplierDialog() async {
    final nameController = TextEditingController();
    final companyController = TextEditingController();
    final phoneController = TextEditingController();
    final taxController = TextEditingController();
    final notesController = TextEditingController();

    final supplier = await showDialog<Supplier>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة مورد جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المورد *',
                  prefixIcon: Icon(Icons.local_shipping),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'اسم الشركة',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'الهاتف / واتساب',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: taxController,
                decoration: const InputDecoration(
                  labelText: 'الرقم الضريبي',
                  prefixIcon: Icon(Icons.receipt_long),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(
                ctx,
                Supplier(
                  id: '',
                  name: name,
                  companyName: companyController.text.trim().isEmpty
                      ? null
                      : companyController.text.trim(),
                  phone: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  whatsapp: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  taxNumber: taxController.text.trim().isEmpty
                      ? null
                      : taxController.text.trim(),
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                ),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    nameController.dispose();
    companyController.dispose();
    phoneController.dispose();
    taxController.dispose();
    notesController.dispose();

    if (supplier == null) return;
    final repo = ref.read(productRepositoryProvider);
    final id = await repo.createSupplier(supplier);
    if (!mounted) return;
    setState(() => _supplier = supplier.copyWith(id: id));
    ref.invalidate(suppliersStreamProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إضافة المورد واختياره للفاتورة'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _save() async {
    if (_supplier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اختر المورد أولاً')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')),
      );
      return;
    }
    setState(() => _loading = true);

    final items = _items
        .where((it) => it.quantity > 0 && it.unitPrice > 0)
        .map(
          (it) => InvoiceItem(
            id: it.productId ?? '',
            productId: it.productId,
            productName: it.name,
            quantity: it.quantity,
            unitPrice: it.unitPrice,
          ),
        )
        .toList();

    final invoice = PurchaseInvoice(
      id: '',
      invoiceNumber: '',
      supplierId: _supplier!.id,
      supplierName: _supplier!.name,
      items: items,
      discount: _discount,
      taxAmount: _taxAmount,
      paidAmount: _paidAmount,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      invoiceDate: DateTime.now(),
    )..calculateTotals();

    final notifier = ref.read(purchaseListProvider.notifier);
    final ok = (await notifier.createPurchase(invoice)) != null;

    // Update purchased products: raise stock and use the last purchase price
    // as the new cost (last purchase price).
    if (ok) {
      final productRepo = ref.read(productRepositoryProvider);
      for (final item in items) {
        if (item.productId == null) continue;
        try {
          final product = await productRepo.getProduct(item.productId!);
          if (product != null) {
            await productRepo.updateProduct(
              product.copyWith(
                costPrice: item.unitPrice,
                currentStock: product.currentStock + item.quantity,
              ),
            );
          }
        } catch (e) {
          // best-effort stock sync
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ فاتورة الشراء')));
        context.go('/purchases');
      }
    } else if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('فشل الحفظ، حاول مرة أخرى')));
    }
  }
}

/// Line item used while composing a purchase invoice.
class _PLineItem {
  String? productId;
  String name = '';
  double quantity = 1;
  double unitPrice = 0;

  _PLineItem({
    this.productId,
    this.name = '',
    this.quantity = 1,
    this.unitPrice = 0,
  });
}

/// Modal bottom sheet to pick a product.
class _AddItemSheet extends StatefulWidget {
  final List<Product> products;
  const _AddItemSheet({required this.products});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.products
        : widget.products
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_query.toLowerCase()) ||
                    (p.nameAr ?? '').toLowerCase().contains(
                      _query.toLowerCase(),
                    ),
              )
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CustomSearchBar(
                hintText: 'بحث عن منتج...',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('لا توجد منتجات مطابقة'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        return ListTile(
                          leading: const Icon(Icons.inventory_2),
                          title: Text(p.name),
                          subtitle: Text(
                            'التكلفة: ${p.costPrice.toStringAsFixed(2)} ج.م',
                          ),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A numeric editable field that keeps its own controller across rebuilds.
class _NumberField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: widget.label, isDense: true),
      onChanged: (value) => widget.onChanged(double.tryParse(value) ?? 0),
    );
  }
}

/// A money input field that keeps its own controller across rebuilds.
class _MoneyField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _MoneyField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.attach_money),
      ),
      onChanged: (value) => widget.onChanged(double.tryParse(value) ?? 0),
    );
  }
}
