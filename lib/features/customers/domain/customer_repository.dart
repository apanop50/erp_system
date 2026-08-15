/// Customer Repository
///
/// Handles all Firestore operations for customers and payments.
/// Supports real-time streams, search, and customer balance management.
import 'package:uuid/uuid.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/services/local_store.dart';
import '../../../core/constants/app_constants.dart';
import 'customer_model.dart';

/// Repository for customer-related Firestore operations.
class CustomerRepository {
  final FirestoreService _firestoreService;
  static const String _collection = 'partners';
  static const String _paymentsCollection = 'payments';

  final Uuid _uuid = const Uuid();

  CustomerRepository(this._firestoreService);

  /// Creates a new customer.
  /// Always writes a local backup first so saving never hangs on the network.
  Future<String> createCustomer(Customer customer) async {
    final id = customer.id.isEmpty ? _uuid.v4() : customer.id;
    final safe = customer.copyWith(id: id);
    LocalStore.put(LocalStore.customerPrefix, id, safe.toMap());
    try {
      await _firestoreService.createWithId(_collection, id, safe.toMap());
    } catch (e) {
      // Local backup saved; Firestore sync happens when connectivity returns.
    }
    return id;
  }

  /// Gets a customer by ID.
  /// Falls back to the local backup when Firestore is unreachable.
  Future<Customer?> getCustomer(String id) async {
    try {
      final map = await _firestoreService.getById(_collection, id);
      if (map != null) return Customer.fromMap(map);
    } catch (e) {
      // Fall through to local.
    }
    final local = LocalStore.get(LocalStore.customerPrefix, id);
    if (local == null) return null;
    local['id'] = id;
    return Customer.fromMap(local);
  }

  /// Gets a real-time stream of a customer.
  Stream<Customer?> streamCustomer(String id) {
    return _firestoreService.streamById(_collection, id).map(
      (map) => map == null ? null : Customer.fromMap(map),
    );
  }

  /// Gets all customers with optional filters.
  Future<List<Customer>> getAllCustomers({
    CustomerType? customerType,
    bool? isActive,
    int? limit,
  }) async {
    final where = <List<dynamic>>[];
    if (customerType != null) {
      where.add(['customerType', '==', customerType.name]);
    }
    if (isActive != null) where.add(['isActive', '==', isActive]);

    try {
      final maps = await _firestoreService.getAll(
        collection: _collection,
        where: where,
        orderBy: 'name',
        limit: limit,
      );
      return maps.map(Customer.fromMap).toList();
    } catch (e) {
      // Fall back to local backup when Firestore is unreachable.
      return LocalStore.getAll(LocalStore.customerPrefix)
          .where((m) => m['isDeleted'] != true)
          .where((m) =>
              isActive == null || (m['isActive'] as bool? ?? true) == isActive)
          .map(Customer.fromMap)
          .toList();
    }
  }

  /// Gets a real-time stream of all customers.
  Stream<List<Customer>> streamAllCustomers({
    CustomerType? customerType,
    bool? isActive,
  }) {
    final where = <List<dynamic>>[];
    if (customerType != null) {
      where.add(['customerType', '==', customerType.name]);
    }
    if (isActive != null) where.add(['isActive', '==', isActive]);

    return _firestoreService.streamAll(
      collection: _collection,
      where: where,
      orderBy: 'name',
    ).map((maps) => maps.map(Customer.fromMap).toList());
  }

  /// Updates a customer.
  Future<void> updateCustomer(Customer customer) async {
    LocalStore.put(LocalStore.customerPrefix, customer.id, customer.toMap());
    try {
      await _firestoreService.update(_collection, customer.id, customer.toMap());
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Updates customer account balance.
  Future<void> updateBalance(String customerId, double newBalance) async {
    final existing =
        LocalStore.get(LocalStore.customerPrefix, customerId) ?? {'id': customerId};
    existing['accountBalance'] = newBalance;
    existing['balance'] = newBalance;
    LocalStore.put(LocalStore.customerPrefix, customerId, existing);
    try {
      await _firestoreService.update(_collection, customerId, {
        'accountBalance': newBalance,
      });
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Deletes a customer (soft delete).
  Future<void> deleteCustomer(String id) async {
    LocalStore.delete(LocalStore.customerPrefix, id);
    try {
      await _firestoreService.delete(_collection, id);
    } catch (e) {
      // Removed locally.
    }
  }

  /// Searches customers by name, phone, or company.
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final nameResults = await _firestoreService.search(
        collection: _collection,
        searchField: 'name',
        searchValue: query,
        limit: 20,
      );

      final phoneResults = await _firestoreService.search(
        collection: _collection,
        searchField: 'phone',
        searchValue: query,
        limit: 20,
      );

      final merged = <String, Map<String, dynamic>>{};
      for (final map in [...nameResults, ...phoneResults]) {
        merged[map['id'] as String] = map;
      }

      return merged.values.map(Customer.fromMap).toList();
    } catch (e) {
      // Fall back to local search when Firestore is unreachable.
      final lower = query.toLowerCase();
      return LocalStore.getAll(LocalStore.customerPrefix)
          .where((m) {
            final name = (m['name'] as String? ?? '').toLowerCase();
            final phone = (m['phone'] as String? ?? '').toLowerCase();
            final company = (m['companyName'] as String? ?? '').toLowerCase();
            return name.contains(lower) ||
                phone.contains(lower) ||
                company.contains(lower);
          })
          .map(Customer.fromMap)
          .toList();
    }
  }

  /// Counts total customers.
  Future<int> countCustomers() async {
    return _firestoreService.count(_collection);
  }

  // ==================== PAYMENTS ====================

  /// Creates a payment record.
  Future<String> createPayment(Payment payment) async {
    return _firestoreService.create(_paymentsCollection, payment.toMap());
  }

  /// Gets payments for a customer.
  Future<List<Payment>> getCustomerPayments(String customerId) async {
    final maps = await _firestoreService.getAll(
      collection: _paymentsCollection,
      where: [['customerId', '==', customerId]],
      orderBy: 'date',
      descending: true,
    );
    return maps.map(Payment.fromMap).toList();
  }

  /// Gets a real-time stream of customer payments.
  Stream<List<Payment>> streamCustomerPayments(String customerId) {
    return _firestoreService.streamAll(
      collection: _paymentsCollection,
      where: [['customerId', '==', customerId]],
      orderBy: 'date',
      descending: true,
    ).map((maps) => maps.map(Payment.fromMap).toList());
  }

  /// Deletes a payment.
  Future<void> deletePayment(String id) async {
    await _firestoreService.delete(_paymentsCollection, id);
  }
}

