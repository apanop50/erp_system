/// Sales Providers
///
/// Riverpod providers for the sales module.
/// Manages sales invoices, purchase invoices, expenses, representatives,
/// hotels, and printed bag orders.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/sales_model.dart';
import '../../domain/sales_repository.dart';
import '../services/invoice_pdf_service.dart';

/// Provider for the SalesRepository instance.
final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final firestoreService = FirestoreService();
  return SalesRepository(firestoreService);
});

/// Provider for the PDF service.
final invoicePdfServiceProvider = Provider<InvoicePdfService>((ref) {
  return InvoicePdfService.instance;
});

/// Provider for a customer's invoices stream.
final customerInvoicesStreamProvider =
    StreamProvider.family<List<SalesInvoice>, String>((ref, customerId) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.streamAllInvoices(customerId: customerId);
});

// ==================== SALES INVOICES ====================

/// State notifier for sales invoice list.
class InvoiceListNotifier extends StateNotifier<AsyncValue<List<SalesInvoice>>> {
  final SalesRepository _repository;

  InvoiceListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadInvoices();
  }

  /// Loads all invoices from Firestore.
  Future<void> loadInvoices({
    String? customerId,
    InvoiceStatus? status,
  }) async {
    state = const AsyncValue.loading();
    try {
      final invoices = await _repository.getAllInvoices(
        customerId: customerId,
        status: status,
      );
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new invoice.
  Future<String?> createInvoice(SalesInvoice invoice) async {
    try {
      final id = await _repository.createInvoice(invoice);
      await loadInvoices();
      return id;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Updates an invoice.
  Future<bool> updateInvoice(SalesInvoice invoice) async {
    try {
      await _repository.updateInvoice(invoice);
      await loadInvoices();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Deletes an invoice.
  Future<bool> deleteInvoice(String id) async {
    try {
      await _repository.deleteInvoice(id);
      await loadInvoices();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Provider for invoice list state.
final invoiceListProvider =
    StateNotifierProvider<InvoiceListNotifier, AsyncValue<List<SalesInvoice>>>(
        (ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return InvoiceListNotifier(repository);
});

/// Provider for a single invoice stream.
final invoiceStreamProvider =
    StreamProvider.family<SalesInvoice?, String>((ref, id) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.streamInvoice(id);
});

// ==================== PURCHASE INVOICES ====================

/// Provider for purchase invoices stream.
final purchaseInvoicesStreamProvider =
    StreamProvider<List<PurchaseInvoice>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.streamAllPurchaseInvoices();
});

/// State notifier for purchase invoice list.
class PurchaseListNotifier
    extends StateNotifier<AsyncValue<List<PurchaseInvoice>>> {
  final SalesRepository _repository;

  PurchaseListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadPurchases();
  }

  /// Loads all purchase invoices (with local fallback).
  Future<void> loadPurchases() async {
    state = const AsyncValue.loading();
    try {
      final purchases = await _repository.getAllPurchaseInvoices();
      state = AsyncValue.data(purchases);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new purchase invoice.
  Future<String?> createPurchase(PurchaseInvoice invoice) async {
    try {
      final id = await _repository.createPurchaseInvoice(invoice);
      await loadPurchases();
      return id;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Updates a purchase invoice.
  Future<bool> updatePurchase(PurchaseInvoice invoice) async {
    try {
      await _repository.updatePurchaseInvoice(invoice);
      await loadPurchases();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Deletes a purchase invoice.
  Future<bool> deletePurchase(String id) async {
    try {
      await _repository.deletePurchaseInvoice(id);
      await loadPurchases();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Provider for purchase invoice list state.
final purchaseListProvider =
    StateNotifierProvider<PurchaseListNotifier, AsyncValue<List<PurchaseInvoice>>>(
        (ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return PurchaseListNotifier(repository);
});

// ==================== EXPENSES ====================

/// State notifier for expense list.
class ExpenseListNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final SalesRepository _repository;

  ExpenseListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  /// Loads all expenses from Firestore.
  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final expenses = await _repository.getAllExpenses();
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Creates a new expense.
  Future<String?> createExpense(Expense expense) async {
    try {
      final id = await _repository.createExpense(expense);
      await loadExpenses();
      return id;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Updates an expense.
  Future<bool> updateExpense(Expense expense) async {
    try {
      await _repository.updateExpense(expense);
      await loadExpenses();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }

  /// Deletes an expense.
  Future<bool> deleteExpense(String id) async {
    try {
      await _repository.deleteExpense(id);
      await loadExpenses();
      return true;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return false;
    }
  }
}

/// Provider for expense list state.
final expenseListProvider =
    StateNotifierProvider<ExpenseListNotifier, AsyncValue<List<Expense>>>(
        (ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return ExpenseListNotifier(repository);
});

// ==================== REPRESENTATIVES ====================

/// Provider for representatives stream.
final representativesStreamProvider =
    StreamProvider<List<SalesRepresentative>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.streamAllRepresentatives();
});

// ==================== HOTELS ====================

/// Provider for hotels stream.
final hotelsStreamProvider = StreamProvider<List<Hotel>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.streamAllHotels();
});

// ==================== PRINTED ORDERS ====================

/// Provider for printed orders stream.
final printedOrdersStreamProvider =
    StreamProvider<List<PrintedBagOrder>>((ref) {
  final repository = ref.watch(salesRepositoryProvider);
  return repository.streamAllPrintedOrders();
});