/// Products Page
///
/// Main products list page for the ERP system.
/// Displays products in a responsive grid/list with search, filter, and CRUD actions.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/product_providers.dart';
import '../../domain/product_model.dart';

/// Products list page widget.
class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'استيراد Excel',
            onPressed: () {
              // TODO: Implement Excel import
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('استيراد Excel - قريباً')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'تصدير Excel',
            onPressed: () {
              // TODO: Implement Excel export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تصدير Excel - قريباً')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              hintText: 'بحث بالاسم أو الباركود...',
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _isSearching = true);
                  ref.read(productListProvider.notifier).searchProducts(value);
                } else {
                  setState(() => _isSearching = false);
                  ref.read(productListProvider.notifier).loadProducts();
                }
              },
              onClear: () {
                _searchController.clear();
                setState(() => _isSearching = false);
                ref.read(productListProvider.notifier).loadProducts();
              },
            ),
          ),
          // Products list
          Expanded(
            child: productsAsync.when(
              loading: () => const LoadingWidget(message: 'جاري تحميل المنتجات...'),
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
                        ref.read(productListProvider.notifier).loadProducts();
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2,
                    title: 'لا توجد منتجات',
                    subtitle: 'لم يتم إضافة أي منتجات بعد',
                    actionLabel: 'إضافة منتج جديد',
                    onAction: () => context.go('/products/form'),
                  );
                }
                return _buildProductsGrid(context, products);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/products/form'),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Builds the responsive products grid.
  Widget _buildProductsGrid(BuildContext context, List<Product> products) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenWidth > 1200
        ? 5
        : screenWidth > 900
            ? 4
            : screenWidth > 600
                ? 3
                : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(context, product, index);
      },
    );
  }

  /// Builds a single product card.
  Widget _buildProductCard(BuildContext context, Product product, int index) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.go('/products/form', extra: product.id),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: AppColors.primary.withAlpha(26),
                ),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: AppColors.primary,
                      ),
              ),
            ),
            // Product info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.nameAr != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        product.nameAr!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${product.sellingPrice.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: product.isLowStock
                                ? AppColors.error.withAlpha(26)
                                : AppColors.success.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'مخزون: ${product.currentStock.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: product.isLowStock
                                  ? AppColors.error
                                  : AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1);
  }
}
