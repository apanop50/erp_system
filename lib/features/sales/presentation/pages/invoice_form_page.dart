/// Invoice Form Page
///
/// Create or edit a sales invoice. Supports selecting a customer (with
/// automatic price based on customer type), adding/removing line items,
/// discount, tax percentage, paid amount and sales representative.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../customers/domain/customer_model.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../products/domain/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Invoice form page.
class InvoiceFormPage extends ConsumerStatefulWidget {
  final String? invoiceId;

  const InvoiceFormPage({super.key, this.invoiceId});

  @override
  ConsumerState<InvoiceFormPage> createState() => _InvoiceFormPageState();
}

class _InvoiceFormPageState extends ConsumerState<InvoiceFormPage> {
  final _notesController = TextEditingController();
  Customer? _customer;
  SalesRepresentative? _rep;
  final List<_LineItem> _items = [];
  double _discount = 0;
  double _taxPercentage = 0;
  double _paidAmount = 0;
  bool _loading = false;

  bool get _isEdit => widget.invoiceId != null;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal =>
      _items.fold(0.0, (sum, item) => sum + item.quantity * item.unitPrice);
  double get _afterDiscount => _subtotal - _discount;
  double get _taxAmount => _afterDiscount * (_taxPercentage / 100);
  double get _grandTotal => _afterDiscount + _taxAmount;
  double get _totalCost =>
      _items.fold(0.0, (sum, item) => sum + item.quantity * item.costPrice);
  double get _profit => _afterDiscount - _totalCost;

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);
    final productsAsync = ref.watch(productListProvider);
    final repsAsync = ref.watch(representativesStreamProvider);
    final invoiceAsync = _isEdit
        ? ref.watch(invoiceStreamProvider(widget.invoiceId!))
        : AsyncValue<SalesInvoice?>.data(null);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل فاتورة' : 'فاتورة جديدة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: 'طباعة PDF',
            onPressed: _isEdit
                ? () async {
                    final inv =
                        await ref.read(salesRepositoryProvider).getInvoice(widget.invoiceId!);
                    if (inv != null) {
                      await ref.read(invoicePdfServiceProvider).printInvoicePdf(inv);
                    }
                  }
                : null,
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (invoice) {
          // Prefill once when editing.
          if (_isEdit && !_prefilled && invoice != null) {
            _prefill(invoice);
          }
          return _buildForm(
            customersAsync: customersAsync,
            productsAsync: productsAsync,
            repsAsync: repsAsync,
          );
        },
      ),
    );
  }

  bool _prefilled = false;

  void _prefill(SalesInvoice invoice) {
    _prefilled = true;
    _discount = invoice.discount;
    _taxPercentage = invoice.taxPercentage;
    _paidAmount = invoice.paidAmount;
    _notesController.text = invoice.notes ?? '';
    for (final it in invoice.items) {
      _items.add(_LineItem(
        productId: it.productId ?? it.id,
        name: it.productName,
        quantity: it.quantity,
        unitPrice: it.unitPrice,
        costPrice: it.costPrice,
      ));
    }
    if (mounted) setState(() {});
  }
Widget _buildForm({
    required AsyncValue<List<Customer>> customersAsync,
    required AsyncValue<List<Product>> productsAsync,
    required AsyncValue<List<SalesRepresentative>> repsAsync,
  }) {
    final customers = customersAsync.valueOrNull ?? const <Customer>[];
    final products = productsAsync.valueOrNull ?? const <Product>[];
    final reps = repsAsync.valueOrNull ?? const <SalesRepresentative>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Customer + representative selection
          _buildCustomerSelector(customers),
          const SizedBox(height: 12),
          _buildRepSelector(reps),
          const SizedBox(height: 16),

          // Line items
          const SectionHeader(title: 'الأصناف', icon: Icons.shopping_bag),
          const SizedBox(height: 8),
          ..._items.asMap().entries.map((entry) => _buildItemRow(
                index: entry.key,
                item: entry.value,
                products: products,
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _items.add(_LineItem()));
            },
            icon: const Icon(Icons.add),
            label: const Text('إضافة صنف'),
          ),
          const SizedBox(height: 16),

          // Totals & payments
          _buildTotalsCard(),
          const SizedBox(height: 16),

          // Notes & save
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_isEdit ? 'حفظ التعديلات' : 'حفظ الفاتورة'),
          ),
        ],
      ),
    );
  }
Widget _buildCustomerSelector(List<Customer> customers) {
    return DropdownButtonFormField<Customer>(
      initialValue: _customer,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'العميل',
        border: OutlineInputBorder(),
      ),
      items: customers
          .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
          .toList(),
      onChanged: (value) => setState(() => _customer = value),
    );
  }

  Widget _buildRepSelector(List<SalesRepresentative> reps) {
    return DropdownButtonFormField<SalesRepresentative>(
      initialValue: _rep,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'مندوب المبيعات',
        border: OutlineInputBorder(),
      ),
      items: reps
          .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
          .toList(),
      onChanged: (value) => setState(() => _rep = value),
    );
  }

  Widget _buildItemRow({
    required int index,
    required _LineItem item,
    required List<Product> products,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: item.productId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'المنتج',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: products
                        .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        item.productId = value;
                        final p = _findProduct(products, value);
                        item.name = p?.name ?? '';
                        item.unitPrice = _priceFor(p);
                        item.costPrice = p?.costPrice ?? 0;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numField(
                    label: 'الكمية',
                    initial: item.quantity,
                    onChanged: (v) => item.quantity = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(
                    label: 'سعر الوحدة',
                    initial: item.unitPrice,
                    onChanged: (v) => item.unitPrice = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Product? _findProduct(List<Product> products, String? id) {
    if (id == null) return null;
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  double _priceFor(Product? p) {
    if (p == null) return 0;
    final isHotel = _customer?.customerType == CustomerType.hotel;
    return isHotel ? p.hotelPrice : p.sellingPrice;
  }
Widget _buildTotalsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _totalRow('الإجمالي الفرعي', _subtotal),
            Row(
              children: [
                Expanded(
                  child: _numField(
                    label: 'الخصم',
                    initial: _discount,
                    onChanged: (v) => _discount = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(
                    label: 'الضريبة %',
                    initial: _taxPercentage,
                    onChanged: (v) => _taxPercentage = v,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(
                    label: 'المدفوع',
                    initial: _paidAmount,
                    onChanged: (v) => _paidAmount = v,
                  ),
                ),
              ],
            ),
            const Divider(),
            _totalRow('ضريبة', _taxAmount),
            _totalRow('الإجمالي', _grandTotal, bold: true),
            _totalRow('المتبقي', (_grandTotal - _paidAmount), bold: true),
            const Divider(),
            _totalRow('تكلفة البضاعة', _totalCost),
            _totalRow(
              'الربح (البيع - الشراء)',
              _profit,
              bold: true,
              color: _profit >= 0 ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
          ),
          Text(
            '${value.toStringAsFixed(2)} ج.م',
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : null,
                color: color ?? AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _numField({
    required String label,
    required double initial,
    required ValueChanged<double> onChanged,
  }) {
    return _EditableNumberField(
      label: label,
      initial: initial,
      onChanged: onChanged,
    );
  }

  Future<void> _save() async {
    if (_customer == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اختر العميل أولاً')),
        );
      }
      return;
    }
    if (_items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أضف صنفاً واحداً على الأقل')),
        );
      }
      return;
    }

    setState(() => _loading = true);

    final items = _items
        .where((it) => it.quantity > 0 && it.unitPrice > 0)
        .map((it) => InvoiceItem(
              id: '', // id may be set by repository/services
              productId: it.productId,
              productName: it.name,
              quantity: it.quantity,
              unitPrice: it.unitPrice,
              costPrice: it.costPrice,
            ))
        .toList()
        .map((e) {
      e.calculateTotal();
      return e;
    }).toList();

    final now = DateTime.now();
    final existing = widget.invoiceId != null
        ? await ref.read(salesRepositoryProvider).getInvoice(widget.invoiceId!)
        : null;

    final invoice = SalesInvoice(
      id: existing?.id ?? '',
      invoiceNumber: existing?.invoiceNumber ?? '',
      customerId: _customer!.id,
      customerName: _customer!.name,
      salesRepId: _rep?.id,
      salesRepName: _rep?.name,
      items: items,
      discount: _discount,
      taxPercentage: _taxPercentage,
      paidAmount: _paidAmount,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      invoiceDate: existing?.invoiceDate ?? now,
      createdAt: existing?.createdAt,
      status: existing?.status ?? InvoiceStatus.unpaid,
    )..calculateTotals();

    final notifier = ref.read(invoiceListProvider.notifier);
    final ok = _isEdit
        ? await notifier.updateInvoice(invoice)
        : (await notifier.createInvoice(invoice)) != null;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'تم الحفظ' : 'فشل الحفظ')),
      );
      if (ok) context.go('/sales');
    }
  }
}

/// Mutable line item used while composing the invoice.
/// A numeric text field that keeps its own controller across rebuilds.
class _EditableNumberField extends StatefulWidget {
  final String label;
  final double initial;
  final ValueChanged<double> onChanged;

  const _EditableNumberField({
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<_EditableNumberField> createState() => _EditableNumberFieldState();
}

class _EditableNumberFieldState extends State<_EditableNumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial.toStringAsFixed(0));
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
class _LineItem {
  String? productId;
  String name = '';
  double quantity = 1;
  double unitPrice = 0;
  double costPrice = 0;

  _LineItem({
    this.productId,
    this.name = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.costPrice = 0,
  });
}