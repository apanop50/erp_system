/// Product Providers
///
/// Riverpod providers for the products module.
/// Manages product list, search, filters, and CRUD operations.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../domain/product_model.dart';
import '../../domain/product_repository.dart';

/// Provider for the ProductRepository instance.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final firestoreService = FirestoreService();
  return ProductRepository(firestoreService);
});

/// State notifier for product list.
class ProductListNotifier extends StateNotifier<AsyncValue<List<Product>>> {
  final ProductRepository _repository;

  ProductListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadProducts();
  }

  /// Loads all products from Firestore.
  Future<void> loadProducts({bool? isActive}) async {
    state = const AsyncValue.loading();
    try {
      final products = await _repository.getAllProducts(isActive: isActive);
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Searches products by query.
  Future<void> searchProducts(String query) async {
    if (query.isEmpty) {
      loadProducts();
      return;
    }
    state = const AsyncValue.loading();
    try {
      final products = await _repository.searchProducts(query);
      state = AsyncValue.data(products);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new product.
  Future<String?> createProduct(Product product) async {
    try {
      final id = await _repository.createProduct(product);
      await loadProducts();
      return id;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Updates a product.
  Future<bool> updateProduct(Product product) async {
    try {
      await _repository.updateProduct(product);
      await loadProducts();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Deletes a product.
  Future<bool> deleteProduct(String id) async {
    try {
      await _repository.deleteProduct(id);
      await loadProducts();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Provider for product list state.
final productListProvider =
    StateNotifierProvider<ProductListNotifier, AsyncValue<List<Product>>>(
        (ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductListNotifier(repository);
});

/// Provider for a single product stream.
final productStreamProvider = StreamProvider.family<Product?, String>((ref, id) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.streamProduct(id);
});

/// Provider for categories stream.
final categoriesStreamProvider = StreamProvider<List<Category>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.streamAllCategories();
});

/// Provider for suppliers stream.
final suppliersStreamProvider = StreamProvider<List<Supplier>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.streamAllSuppliers();
});

/// Provider for low stock products.
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getLowStockProducts();
});
