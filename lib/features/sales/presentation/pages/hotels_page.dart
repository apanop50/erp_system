import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../products/domain/product_model.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../domain/sales_model.dart';
import '../providers/sales_providers.dart';

/// Hotels page.
class HotelsPage extends ConsumerWidget {
  const HotelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hotelsAsync = ref.watch(hotelsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الفنادق')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        onPressed: () => _showAddHotelDialog(context, ref),
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
      body: hotelsAsync.when(
        loading: () => const LoadingWidget(),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (hotels) {
          if (hotels.isEmpty) {
            return const EmptyState(
              icon: Icons.hotel,
              title: 'لا توجد فنادق',
              subtitle: 'أضف فندقاً لعرض الأسعار الخاصة',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: hotels.length,
            itemBuilder: (context, index) => _HotelCard(hotel: hotels[index]),
          );
        },
      ),
    );
  }

  Future<void> _showAddHotelDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final customerIdController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فندق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'اسم الفندق'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'الهاتف (اختياري)'),
            ),
            TextField(
              controller: customerIdController,
              decoration: const InputDecoration(labelText: 'معرّف العميل (اختياري)'),
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
              await repo.createHotel(Hotel(
                id: '',
                customerId: customerIdController.text.trim(),
                name: name,
                phone: phoneController.text.trim().isEmpty
                    ? null
                    : phoneController.text.trim(),
              ));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
class _HotelCard extends ConsumerWidget {
  final Hotel hotel;

  const _HotelCard({required this.hotel});

  Future<void> _printPriceList(BuildContext context, WidgetRef ref) async {
    await ref.read(productListProvider.notifier).loadProducts();
    final products = (ref.read(productListProvider).valueOrNull ?? const <Product>[])
        .where((p) => p.isActive)
        .toList();
    await ref
        .read(invoicePdfServiceProvider)
        .printHotelPriceListPdf(hotel: hotel, products: products);
  }

  Future<void> _editPrices(BuildContext context, WidgetRef ref) async {
    await ref.read(productListProvider.notifier).loadProducts();
    final products =
        ref.read(productListProvider).valueOrNull ?? const <Product>[];
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PriceEditor(hotel: hotel, products: products),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(26),
          child: const Icon(Icons.hotel, color: AppColors.primary),
        ),
        title: Text(hotel.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: (hotel.phone != null && hotel.phone!.isNotEmpty)
            ? Text(hotel.phone!)
            : Text('${hotel.specialPrices.length} سعر خاص'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.price_change),
              tooltip: 'تعديل الأسعار',
              onPressed: () => _editPrices(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: AppColors.error),
              tooltip: 'قائمة أسعار PDF',
              onPressed: () => _printPriceList(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
/// Bottom sheet to adjust special prices for each product of a hotel.
class _PriceEditor extends ConsumerStatefulWidget {
  final Hotel hotel;
  final List<Product> products;

  const _PriceEditor({required this.hotel, required this.products});

  @override
  ConsumerState<_PriceEditor> createState() => _PriceEditorState();
}

class _PriceEditorState extends ConsumerState<_PriceEditor> {
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (final p in widget.products) {
      final v = widget.hotel.specialPrices[p.id] ?? p.hotelPrice;
      _controllers[p.id] = TextEditingController(text: v.toStringAsFixed(0));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'أسعار ${widget.hotel.name} الخاصة',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.products.length,
              itemBuilder: (context, index) {
                final p = widget.products[index];
                return ListTile(
                  dense: true,
                  title: Text(p.name),
                  subtitle: Text('السعر الافتراضي: ${p.hotelPrice.toStringAsFixed(2)} ج.م'),
                  trailing: SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _controllers[p.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'السعر',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('حفظ الأسعار'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(salesRepositoryProvider);
    for (final p in widget.products) {
      final value = double.tryParse(_controllers[p.id]!.text);
      if (value != null && value > 0) {
        await repo.updateHotelPrice(widget.hotel.id, p.id, value);
      }
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الأسعار')),
      );
    }
  }
}