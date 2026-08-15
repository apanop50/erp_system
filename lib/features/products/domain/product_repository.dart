/// Product Repository
///
/// Handles all Firestore operations for products, categories, and suppliers.
/// Uses the generic FirestoreService for CRUD operations with real-time streams.
import 'package:uuid/uuid.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/services/local_store.dart';
import 'product_model.dart';

/// Repository for product-related Firestore operations.
class ProductRepository {
  final FirestoreService _firestoreService;
  static const String _collection = 'products';
  static const String _categoriesCollection = 'categories';
  static const String _suppliersCollection = 'suppliers';

  final Uuid _uuid = const Uuid();

  ProductRepository(this._firestoreService);

  // ==================== PRODUCTS ====================

  /// Creates a new product in Firestore.
  /// Always writes a local backup first so saving never hangs on the network.
  Future<String> createProduct(Product product) async {
    final id = product.id.isEmpty ? _uuid.v4() : product.id;
    final safe = product.copyWith(id: id);
    LocalStore.put(LocalStore.productPrefix, id, safe.toMap());
    try {
      await _firestoreService.createWithId(_collection, id, safe.toMap());
    } catch (e) {
      // Local backup saved; Firestore sync happens when connectivity returns.
    }
    return id;
  }

  /// Creates a product with a specific ID.
  Future<void> createProductWithId(Product product) async {
    LocalStore.put(LocalStore.productPrefix, product.id, product.toMap());
    try {
      await _firestoreService.createWithId(
        _collection,
        product.id,
        product.toMap(),
      );
    } catch (e) {
      // Local backup saved.
    }
  }

  /// Gets a product by ID.
  /// Falls back to the local backup when Firestore is unreachable.
  Future<Product?> getProduct(String id) async {
    try {
      final map = await _firestoreService.getById(_collection, id);
      if (map != null) return Product.fromMap(map);
    } catch (e) {
      // Fall through to local.
    }
    final local = LocalStore.get(LocalStore.productPrefix, id);
    if (local == null) return null;
    local['id'] = id;
    return Product.fromMap(local);
  }

  /// Gets a real-time stream of a product.
  Stream<Product?> streamProduct(String id) {
    return _firestoreService
        .streamById(_collection, id)
        .map((map) => map == null ? null : Product.fromMap(map));
  }

  /// Gets all products with optional filters.
  Future<List<Product>> getAllProducts({
    String? categoryId,
    String? supplierId,
    bool? isActive,
    int? limit,
  }) async {
    final where = <List<dynamic>>[];
    if (categoryId != null) where.add(['categoryId', '==', categoryId]);
    if (supplierId != null) where.add(['supplierId', '==', supplierId]);
    if (isActive != null) where.add(['isActive', '==', isActive]);

    try {
      final maps = await _firestoreService.getAll(
        collection: _collection,
        where: where,
        orderBy: 'name',
        limit: limit,
      );
      return maps.map(Product.fromMap).toList();
    } catch (e) {
      // Fall back to local backup when Firestore is unreachable.
      return getAllProductsLocal();
    }
  }

  /// Falls back to the local backup when Firestore is unreachable.
  Future<List<Product>> getAllProductsLocal() async {
    return LocalStore.getAll(
      LocalStore.productPrefix,
    ).where((m) => m['isDeleted'] != true).map(Product.fromMap).toList();
  }

  /// Gets a real-time stream of all products.
  Stream<List<Product>> streamAllProducts({
    String? categoryId,
    bool? isActive,
    int? limit,
  }) {
    final where = <List<dynamic>>[];
    if (categoryId != null) where.add(['categoryId', '==', categoryId]);
    if (isActive != null) where.add(['isActive', '==', isActive]);

    return _firestoreService
        .streamAll(
          collection: _collection,
          where: where,
          orderBy: 'name',
          limit: limit,
        )
        .map((maps) => maps.map(Product.fromMap).toList());
  }

  /// Updates a product.
  Future<void> updateProduct(Product product) async {
    LocalStore.put(LocalStore.productPrefix, product.id, product.toMap());
    try {
      await _firestoreService.update(_collection, product.id, product.toMap());
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Updates product stock.
  Future<void> updateStock(String productId, double newStock) async {
    final existing =
        LocalStore.get(LocalStore.productPrefix, productId) ??
        {'id': productId};
    existing['stock'] = newStock;
    existing['currentStock'] = newStock;
    LocalStore.put(LocalStore.productPrefix, productId, existing);
    try {
      await _firestoreService.update(_collection, productId, {
        'stock': newStock,
      });
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Soft-deletes a product.
  Future<void> deleteProduct(String id) async {
    LocalStore.delete(LocalStore.productPrefix, id);
    try {
      await _firestoreService.delete(_collection, id);
    } catch (e) {
      // Removed locally.
    }
  }

  /// Searches products by name or barcode.
  Future<List<Product>> searchProducts(String query) async {
    try {
      final nameResults = await _firestoreService.search(
        collection: _collection,
        searchField: 'name',
        searchValue: query,
        limit: 20,
      );

      // Also search by barcode
      final barcodeResults = await _firestoreService.search(
        collection: _collection,
        searchField: 'barcode',
        searchValue: query,
        limit: 20,
      );

      // Merge and deduplicate
      final merged = <String, Map<String, dynamic>>{};
      for (final map in [...nameResults, ...barcodeResults]) {
        merged[map['id'] as String] = map;
      }

      return merged.values.map(Product.fromMap).toList();
    } catch (e) {
      // Fall back to local search when Firestore is unreachable.
      final lower = query.toLowerCase();
      return LocalStore.getAll(LocalStore.productPrefix)
          .where((m) {
            final name = (m['name'] as String? ?? '').toLowerCase();
            final nameAr = (m['nameAr'] as String? ?? '').toLowerCase();
            final barcode = (m['barcode'] as String? ?? '').toLowerCase();
            return name.contains(lower) ||
                nameAr.contains(lower) ||
                barcode.contains(lower);
          })
          .map(Product.fromMap)
          .toList();
    }
  }

  /// Gets low stock products.
  Future<List<Product>> getLowStockProducts() async {
    final maps = await _firestoreService.getAll(
      collection: _collection,
      where: [
        ['isActive', '==', true],
      ],
      orderBy: 'stock',
      limit: 20,
    );
    final products = maps.map(Product.fromMap).toList();
    return products.where((p) => p.isLowStock).toList();
  }

  /// Counts total products.
  Future<int> countProducts() async {
    return _firestoreService.count(_collection);
  }

  // ==================== CATEGORIES ====================

  /// Creates a new category.
  Future<String> createCategory(Category category) async {
    return _firestoreService.create(_categoriesCollection, category.toMap());
  }

  /// Gets all categories.
  Future<List<Category>> getAllCategories() async {
    final maps = await _firestoreService.getAll(
      collection: _categoriesCollection,
      orderBy: 'name',
    );
    return maps.map(Category.fromMap).toList();
  }

  /// Gets a real-time stream of all categories.
  Stream<List<Category>> streamAllCategories() {
    return _firestoreService
        .streamAll(collection: _categoriesCollection, orderBy: 'name')
        .map((maps) => maps.map(Category.fromMap).toList());
  }

  /// Updates a category.
  Future<void> updateCategory(Category category) async {
    await _firestoreService.update(
      _categoriesCollection,
      category.id,
      category.toMap(),
    );
  }

  /// Deletes a category.
  Future<void> deleteCategory(String id) async {
    await _firestoreService.delete(_categoriesCollection, id);
  }

  // ==================== SUPPLIERS ====================

  /// Creates a new supplier.
  Future<String> createSupplier(Supplier supplier) async {
    final id = supplier.id.isEmpty ? _uuid.v4() : supplier.id;
    final safe = supplier.copyWith(id: id);
    LocalStore.put(LocalStore.supplierPrefix, id, safe.toMap());
    try {
      await _firestoreService.createWithId(
        _suppliersCollection,
        id,
        safe.toMap(),
      );
    } catch (_) {
      // Local backup saved.
    }
    return id;
  }

  /// Gets all suppliers.
  Future<List<Supplier>> getAllSuppliers() async {
    try {
      final maps = await _firestoreService.getAll(
        collection: _suppliersCollection,
        orderBy: 'name',
      );
      return maps.map(Supplier.fromMap).toList();
    } catch (_) {
      return LocalStore.getAll(
        LocalStore.supplierPrefix,
      ).map(Supplier.fromMap).toList();
    }
  }

  /// Gets a real-time stream of all suppliers.
  Stream<List<Supplier>> streamAllSuppliers() {
    return _firestoreService
        .streamAll(collection: _suppliersCollection, orderBy: 'name')
        .map((maps) => maps.map(Supplier.fromMap).toList());
  }

  /// Gets a supplier by ID.
  Future<Supplier?> getSupplier(String id) async {
    final map = await _firestoreService.getById(_suppliersCollection, id);
    if (map == null) return null;
    return Supplier.fromMap(map);
  }

  /// Updates a supplier.
  Future<void> updateSupplier(Supplier supplier) async {
    LocalStore.put(LocalStore.supplierPrefix, supplier.id, supplier.toMap());
    try {
      await _firestoreService.update(
        _suppliersCollection,
        supplier.id,
        supplier.toMap(),
      );
    } catch (_) {
      // Local backup saved.
    }
  }

  /// Deletes a supplier.
  Future<void> deleteSupplier(String id) async {
    await _firestoreService.delete(_suppliersCollection, id);
  }
}
