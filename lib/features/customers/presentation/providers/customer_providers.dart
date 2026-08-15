/// Customer Providers
///
/// Riverpod providers for the customers module.
/// Manages customer list, search, filters, and CRUD operations.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/customer_model.dart';
import '../../domain/customer_repository.dart';

/// Provider for the CustomerRepository instance.
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final firestoreService = FirestoreService();
  return CustomerRepository(firestoreService);
});

/// State notifier for customer list.
class CustomerListNotifier extends StateNotifier<AsyncValue<List<Customer>>> {
  final CustomerRepository _repository;

  CustomerListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCustomers();
  }

  /// Loads all customers from Firestore.
  Future<void> loadCustomers({
    CustomerType? customerType,
    bool? isActive,
  }) async {
    state = const AsyncValue.loading();
    try {
      final customers = await _repository.getAllCustomers(
        customerType: customerType,
        isActive: isActive,
      );
      state = AsyncValue.data(customers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Searches customers by query.
  Future<void> searchCustomers(String query) async {
    if (query.isEmpty) {
      loadCustomers();
      return;
    }
    state = const AsyncValue.loading();
    try {
      final customers = await _repository.searchCustomers(query);
      state = AsyncValue.data(customers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new customer.
  Future<String?> createCustomer(Customer customer) async {
    try {
      final id = await _repository.createCustomer(customer);
      await loadCustomers();
      return id;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Updates a customer.
  Future<bool> updateCustomer(Customer customer) async {
    try {
      await _repository.updateCustomer(customer);
      await loadCustomers();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Deletes a customer.
  Future<bool> deleteCustomer(String id) async {
    try {
      await _repository.deleteCustomer(id);
      await loadCustomers();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Provider for customer list state.
final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, AsyncValue<List<Customer>>>(
        (ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return CustomerListNotifier(repository);
});

/// Provider for a single customer stream.
final customerStreamProvider =
    StreamProvider.family<Customer?, String>((ref, id) {
  final repository = ref.watch(customerRepositoryProvider);
  return repository.streamCustomer(id);
});

/// Provider for customer payments stream.
final customerPaymentsStreamProvider =
    StreamProvider.family<List<Payment>, String>((ref, customerId) {
  final repository = ref.watch(customerRepositoryProvider);
  return repository.streamCustomerPayments(customerId);
});
