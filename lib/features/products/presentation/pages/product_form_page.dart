/// Product Form Page
///
/// Add/Edit form for products in the ERP system.
/// Contains all product fields including pricing tiers, stock, and categories.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/product_providers.dart';
import '../../domain/product_model.dart';

/// Product form page widget for adding or editing products.
class ProductFormPage extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormPage({super.key, this.productId});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _internalCodeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _hotelPriceController = TextEditingController();
  final _wholesalePriceController = TextEditingController();
  final _currentStockController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _notesController = TextEditingController();
  final _unitController = TextEditingController(text: 'piece');

  bool _isLoading = false;
  bool _isEditing = false;
  String? _selectedCategoryId;
  String? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _isEditing = true;
      _loadProduct();
    }
  }

  /// Loads an existing product for editing.
  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(productRepositoryProvider);
      final product = await repository.getProduct(widget.productId!);
      if (product != null && mounted) {
        _nameController.text = product.name;
        _nameArController.text = product.nameAr ?? '';
        _nameEnController.text = product.nameEn ?? '';
        _barcodeController.text = product.barcode ?? '';
        _internalCodeController.text = product.internalCode ?? '';
        _costPriceController.text = product.costPrice.toStringAsFixed(2);
        _sellingPriceController.text = product.sellingPrice.toStringAsFixed(2);
        _hotelPriceController.text = product.hotelPrice.toStringAsFixed(2);
        _wholesalePriceController.text = product.wholesalePrice.toStringAsFixed(2);
        _currentStockController.text = product.currentStock.toStringAsFixed(0);
        _minimumStockController.text = product.minimumStock.toStringAsFixed(0);
        _notesController.text = product.notes ?? '';
        _unitController.text = product.unit;
        _selectedCategoryId = product.categoryId;
        _selectedSupplierId = product.supplierId;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المنتج: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _nameEnController.dispose();
    _barcodeController.dispose();
    _internalCodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _hotelPriceController.dispose();
    _wholesalePriceController.dispose();
    _currentStockController.dispose();
    _minimumStockController.dispose();
    _notesController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  /// Handles saving the product.
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: widget.productId ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        nameAr: _nameArController.text.trim().isEmpty
            ? null
            : _nameArController.text.trim(),
        nameEn: _nameEnController.text.trim().isEmpty
            ? null
            : _nameEnController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        internalCode: _internalCodeController.text.trim().isEmpty
            ? null
            : _internalCodeController.text.trim(),
        categoryId: _selectedCategoryId,
        costPrice: double.tryParse(_costPriceController.text) ?? 0,
        sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
        hotelPrice: double.tryParse(_hotelPriceController.text) ?? 0,
        wholesalePrice: double.tryParse(_wholesalePriceController.text) ?? 0,
        unit: _unitController.text.trim().isEmpty ? 'piece' : _unitController.text.trim(),
        currentStock: double.tryParse(_currentStockController.text) ?? 0,
        minimumStock: double.tryParse(_minimumStockController.text) ?? 0,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        isActive: true,
      );

      final notifier = ref.read(productListProvider.notifier);
      bool savedOk;
      if (_isEditing) {
        savedOk = await notifier.updateProduct(product);
      } else {
        savedOk = (await notifier.createProduct(product)) != null;
      }

      if (mounted) {
        if (savedOk) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditing ? 'تم تحديث المنتج بنجاح' : 'تم إضافة المنتج بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/products');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل حفظ المنتج. تحقق من الاتصال ثم أعد المحاولة.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final suppliersAsync = ref.watch(suppliersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'تعديل منتج' : 'إضافة منتج جديد'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تأكيد الحذف'),
                    content: const Text('هل تريد حذف هذا المنتج؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(productListProvider.notifier).deleteProduct(widget.productId!);
                  if (mounted) context.go('/products');
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري التحميل...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product image placeholder
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(26),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text('اضغط لإضافة صورة المنتج'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Basic info section
                    _buildSectionTitle('المعلومات الأساسية'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المنتج *',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الرجاء إدخال اسم المنتج';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameArController,
                            decoration: const InputDecoration(
                              labelText: 'الاسم بالعربية',
                              prefixIcon: Icon(Icons.translate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _nameEnController,
                            decoration: const InputDecoration(
                              labelText: 'الاسم بالإنجليزية',
                              prefixIcon: Icon(Icons.translate),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcodeController,
                            decoration: const InputDecoration(
                              labelText: 'الباركود',
                              prefixIcon: Icon(Icons.barcode_reader),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _internalCodeController,
                            decoration: const InputDecoration(
                              labelText: 'الكود الداخلي',
                              prefixIcon: Icon(Icons.code),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Pricing section
                    _buildSectionTitle('الأسعار'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _costPriceController,
                            decoration: const InputDecoration(
                              labelText: 'سعر التكلفة',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sellingPriceController,
                            decoration: const InputDecoration(
                              labelText: 'سعر البيع',
                              prefixIcon: Icon(Icons.sell),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _hotelPriceController,
                            decoration: const InputDecoration(
                              labelText: 'سعر الفنادق',
                              prefixIcon: Icon(Icons.hotel),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _wholesalePriceController,
                            decoration: const InputDecoration(
                              labelText: 'سعر الجملة',
                              prefixIcon: Icon(Icons.store),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stock section
                    _buildSectionTitle('المخزون'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currentStockController,
                            decoration: const InputDecoration(
                              labelText: 'المخزون الحالي',
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minimumStockController,
                            decoration: const InputDecoration(
                              labelText: 'الحد الأدنى للمخزون',
                              prefixIcon: Icon(Icons.warning),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleSave,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isEditing ? 'تحديث المنتج' : 'حفظ المنتج'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Builds a section title.
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
