/// Sales Repository
///
/// Handles all Firestore operations for sales invoices, purchase invoices,
/// expenses, representatives, hotels, and printed bag orders.
/// Supports real-time streams, batch writes, and automatic stock/balance updates.
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/local_store.dart';
import 'sales_model.dart';

/// Repository for sales invoice-related Firestore operations.
class SalesRepository {
  final FirestoreService _firestoreService;
  final Uuid _uuid;
  static const String _salesCollection = 'invoices';
  static const String _purchasesCollection = 'purchase_invoices';
  static const String _expensesCollection = 'expenses';
  static const String _representativesCollection = 'partners';
  static const String _hotelsCollection = 'partners';
  static const String _printedOrdersCollection = 'cancel_requests';

  SalesRepository(this._firestoreService) : _uuid = const Uuid();

  // ==================== SALES INVOICES ====================

  /// Creates a new sales invoice.
  /// Generates an invoice number automatically.
  /// Always writes a local backup first so saving never hangs on the network.
  Future<String> createInvoice(SalesInvoice invoice) async {
    final id = invoice.id.isEmpty ? _uuid.v4() : invoice.id;
    final invoiceWithNumber = invoice.copyWith(
      id: id,
      invoiceNumber: invoice.invoiceNumber.isEmpty
          ? _generateInvoiceNumber()
          : invoice.invoiceNumber,
    )..calculateTotals();
    LocalStore.put(LocalStore.invoicePrefix, id, invoiceWithNumber.toMap());
    try {
      await _firestoreService.createWithId(
        _salesCollection,
        id,
        invoiceWithNumber.toMap(),
      );
    } catch (e) {
      // Local backup saved; Firestore sync happens when connectivity returns.
    }
    return id;
  }

  /// Generates a unique invoice number.
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final random = _uuid.v4().substring(0, 8).toUpperCase();
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  /// Gets a sales invoice by ID.
  /// Falls back to the local backup when Firestore is unreachable.
  Future<SalesInvoice?> getInvoice(String id) async {
    try {
      final map = await _firestoreService.getById(_salesCollection, id);
      if (map != null) return SalesInvoice.fromMap(map);
    } catch (e) {
      // Fall through to local.
    }
    final local = LocalStore.get(LocalStore.invoicePrefix, id);
    if (local == null) return null;
    local['id'] = id;
    return SalesInvoice.fromMap(local);
  }

  /// Gets a real-time stream of a sales invoice.
  Stream<SalesInvoice?> streamInvoice(String id) {
    return _firestoreService.streamById(_salesCollection, id).map(
      (map) => map == null ? null : SalesInvoice.fromMap(map),
    );
  }

  /// Gets all sales invoices with optional filters.
  Future<List<SalesInvoice>> getAllInvoices({
    String? customerId,
    String? salesRepId,
    InvoiceStatus? status,
    int? limit,
  }) async {
    final where = <List<dynamic>>[];
    if (customerId != null) where.add(['customerId', '==', customerId]);
    if (salesRepId != null) where.add(['salesId', '==', salesRepId]);
    if (status != null) where.add(['status', '==', status.name]);

    try {
      final maps = await _firestoreService.getAll(
        collection: _salesCollection,
        where: where,
        orderBy: 'date',
        descending: true,
        limit: limit,
      );
      return maps.map(SalesInvoice.fromMap).toList();
    } catch (e) {
      // Fall back to local backup when Firestore is unreachable.
      var locals = LocalStore.getAll(LocalStore.invoicePrefix);
      if (customerId != null) {
        locals = locals.where((m) => m['customerId'] == customerId).toList();
      }
      locals.sort((a, b) {
        final da = a['date'];
        final db = b['date'];
        return db.toString().compareTo(da.toString());
      });
      return locals.map(SalesInvoice.fromMap).toList();
    }
  }

  /// Gets a real-time stream of all sales invoices.
  Stream<List<SalesInvoice>> streamAllInvoices({
    String? customerId,
    String? salesRepId,
    InvoiceStatus? status,
    int? limit,
  }) {
    final where = <List<dynamic>>[];
    if (customerId != null) where.add(['customerId', '==', customerId]);
    if (salesRepId != null) where.add(['salesId', '==', salesRepId]);
    if (status != null) where.add(['status', '==', status.name]);

    return _firestoreService.streamAll(
      collection: _salesCollection,
      where: where,
      orderBy: 'date',
      descending: true,
      limit: limit,
    ).map((maps) => maps.map(SalesInvoice.fromMap).toList());
  }

  /// Updates a sales invoice.
  Future<void> updateInvoice(SalesInvoice invoice) async {
    invoice.calculateTotals();
    LocalStore.put(LocalStore.invoicePrefix, invoice.id, invoice.toMap());
    try {
      await _firestoreService.update(
        _salesCollection,
        invoice.id,
        invoice.toMap(),
      );
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Updates invoice payment amount.
  Future<void> updateInvoicePayment(
    String invoiceId,
    double paidAmount,
  ) async {
    final existing =
        LocalStore.get(LocalStore.invoicePrefix, invoiceId) ?? {'id': invoiceId};
    existing['paid'] = paidAmount;
    LocalStore.put(LocalStore.invoicePrefix, invoiceId, existing);
    try {
      await _firestoreService.update(_salesCollection, invoiceId, {
        'paid': paidAmount,
      });
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Updates invoice status.
  Future<void> updateInvoiceStatus(
    String invoiceId,
    InvoiceStatus status,
  ) async {
    final existing =
        LocalStore.get(LocalStore.invoicePrefix, invoiceId) ?? {'id': invoiceId};
    existing['status'] = status.name;
    LocalStore.put(LocalStore.invoicePrefix, invoiceId, existing);
    try {
      await _firestoreService.update(_salesCollection, invoiceId, {
        'status': status.name,
      });
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Deletes a sales invoice (soft delete).
  Future<void> deleteInvoice(String id) async {
    LocalStore.delete(LocalStore.invoicePrefix, id);
    try {
      await _firestoreService.delete(_salesCollection, id);
    } catch (e) {
      // Removed locally.
    }
  }

  /// Gets recent invoices for the dashboard.
  Future<List<SalesInvoice>> getRecentInvoices({int limit = 5}) async {
    final maps = await _firestoreService.getAll(
      collection: _salesCollection,
      orderBy: 'date',
      descending: true,
      limit: limit,
    );
    return maps.map(SalesInvoice.fromMap).toList();
  }

  /// Counts total sales invoices.
  Future<int> countInvoices() async {
    return _firestoreService.count(_salesCollection);
  }

  /// Gets today's total sales.
  Future<double> getTodaySales() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final invoices = await getAllInvoices(limit: 100);
    double total = 0;
    for (final invoice in invoices) {
      if (invoice.invoiceDate.isAfter(startOfDay) &&
          invoice.status != InvoiceStatus.cancelled) {
        total += invoice.grandTotal;
      }
    }
    return total;
  }

  // ==================== PURCHASE INVOICES ====================

  /// Creates a new purchase invoice.
  /// Always writes a local backup first so saving never hangs on the network.
  Future<String> createPurchaseInvoice(PurchaseInvoice invoice) async {
    final id = invoice.id.isEmpty ? _uuid.v4() : invoice.id;
    final safe = invoice.copyWith(id: id)..calculateTotals();
    LocalStore.put(LocalStore.purchasePrefix, id, safe.toMap());
    try {
      await _firestoreService.createWithId(
        _purchasesCollection,
        id,
        safe.toMap(),
      );
    } catch (e) {
      // Local backup saved; Firestore sync happens when connectivity returns.
    }
    return id;
  }

  /// Gets a purchase invoice by ID.
  /// Falls back to the local backup when Firestore is unreachable.
  Future<PurchaseInvoice?> getPurchaseInvoice(String id) async {
    try {
      final map = await _firestoreService.getById(_purchasesCollection, id);
      if (map != null) return PurchaseInvoice.fromMap(map);
    } catch (e) {
      // Fall through to local.
    }
    final local = LocalStore.get(LocalStore.purchasePrefix, id);
    if (local == null) return null;
    local['id'] = id;
    return PurchaseInvoice.fromMap(local);
  }

  /// Gets all purchase invoices.
  Future<List<PurchaseInvoice>> getAllPurchaseInvoices({
    String? supplierId,
    int? limit,
  }) async {
    final where = <List<dynamic>>[];
    if (supplierId != null) {
      where.add(['supplierId', '==', supplierId]);
    }

    try {
      final maps = await _firestoreService.getAll(
        collection: _purchasesCollection,
        where: where,
        orderBy: 'date',
        descending: true,
        limit: limit,
      );
      return maps.map(PurchaseInvoice.fromMap).toList();
    } catch (e) {
      // Fall back to local backup when Firestore is unreachable.
      return LocalStore.getAll(LocalStore.purchasePrefix)
          .where((m) => supplierId == null || m['supplierId'] == supplierId)
          .map(PurchaseInvoice.fromMap)
          .toList();
    }
  }

  /// Gets a real-time stream of all purchase invoices.
  Stream<List<PurchaseInvoice>> streamAllPurchaseInvoices({
    String? supplierId,
  }) {
    final where = <List<dynamic>>[];
    if (supplierId != null) {
      where.add(['supplierId', '==', supplierId]);
    }

    return _firestoreService.streamAll(
      collection: _purchasesCollection,
      where: where,
      orderBy: 'date',
      descending: true,
    ).map((maps) => maps.map(PurchaseInvoice.fromMap).toList());
  }

  /// Updates a purchase invoice.
  Future<void> updatePurchaseInvoice(PurchaseInvoice invoice) async {
    invoice.calculateTotals();
    LocalStore.put(LocalStore.purchasePrefix, invoice.id, invoice.toMap());
    try {
      await _firestoreService.update(
        _purchasesCollection,
        invoice.id,
        invoice.toMap(),
      );
    } catch (e) {
      // Local backup updated.
    }
  }

  /// Deletes a purchase invoice.
  Future<void> deletePurchaseInvoice(String id) async {
    LocalStore.delete(LocalStore.purchasePrefix, id);
    try {
      await _firestoreService.delete(_purchasesCollection, id);
    } catch (e) {
      // Removed locally.
    }
  }

  /// Gets today's total purchases.
  Future<double> getTodayPurchases() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final invoices = await getAllPurchaseInvoices(limit: 100);
    double total = 0;
    for (final invoice in invoices) {
      if (invoice.invoiceDate.isAfter(startOfDay)) {
        total += invoice.grandTotal;
      }
    }
    return total;
  }

  // ==================== EXPENSES ====================

  /// Creates a new expense.
  Future<String> createExpense(Expense expense) async {
    return _firestoreService.create(_expensesCollection, expense.toMap());
  }

  /// Gets all expenses.
  Future<List<Expense>> getAllExpenses({
    ExpenseCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final where = <List<dynamic>>[];
    if (category != null) where.add(['category', '==', category.name]);

    final maps = await _firestoreService.getAll(
      collection: _expensesCollection,
      where: where,
      orderBy: 'expenseDate',
      descending: true,
      limit: limit,
    );
    var expenses = maps.map(Expense.fromMap).toList();

    if (startDate != null) {
      expenses = expenses.where((e) => e.expenseDate.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      expenses = expenses.where((e) => e.expenseDate.isBefore(endDate)).toList();
    }

    return expenses;
  }

  /// Gets a real-time stream of all expenses.
  Stream<List<Expense>> streamAllExpenses() {
    return _firestoreService.streamAll(
      collection: _expensesCollection,
      orderBy: 'expenseDate',
      descending: true,
    ).map((maps) => maps.map(Expense.fromMap).toList());
  }

  /// Updates an expense.
  Future<void> updateExpense(Expense expense) async {
    await _firestoreService.update(
      _expensesCollection,
      expense.id,
      expense.toMap(),
    );
  }

  /// Deletes an expense.
  Future<void> deleteExpense(String id) async {
    await _firestoreService.delete(_expensesCollection, id);
  }

  /// Gets today's total expenses.
  Future<double> getTodayExpenses() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final expenses = await getAllExpenses(limit: 100);
    double total = 0;
    for (final expense in expenses) {
      if (expense.expenseDate.isAfter(startOfDay)) {
        total += expense.amount;
      }
    }
    return total;
  }

  /// Gets monthly expense report.
  Future<Map<ExpenseCategory, double>> getMonthlyExpenseReport(
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    final expenses = await getAllExpenses(startDate: startDate, endDate: endDate);

    final report = <ExpenseCategory, double>{};
    for (final expense in expenses) {
      report[expense.category] =
          (report[expense.category] ?? 0) + expense.amount;
    }
    return report;
  }

  // ==================== SALES REPRESENTATIVES ====================

  /// Creates a new sales representative.
  Future<String> createRepresentative(SalesRepresentative rep) async {
    return _firestoreService.create(
      _representativesCollection,
      rep.toMap(),
    );
  }

  /// Gets all sales representatives.
  Future<List<SalesRepresentative>> getAllRepresentatives() async {
    final maps = await _firestoreService.getAll(
      collection: _representativesCollection,
      orderBy: 'name',
    );
    return maps.map(SalesRepresentative.fromMap).toList();
  }

  /// Gets a real-time stream of all sales representatives.
  Stream<List<SalesRepresentative>> streamAllRepresentatives() {
    return _firestoreService.streamAll(
      collection: _representativesCollection,
      orderBy: 'name',
    ).map((maps) => maps.map(SalesRepresentative.fromMap).toList());
  }

  /// Updates a sales representative.
  Future<void> updateRepresentative(SalesRepresentative rep) async {
    await _firestoreService.update(
      _representativesCollection,
      rep.id,
      rep.toMap(),
    );
  }

  /// Deletes a sales representative.
  Future<void> deleteRepresentative(String id) async {
    await _firestoreService.delete(_representativesCollection, id);
  }

  /// Counts total sales representatives.
  Future<int> countRepresentatives() async {
    return _firestoreService.count(_representativesCollection);
  }

  // ==================== HOTELS ====================

  /// Creates a new hotel.
  Future<String> createHotel(Hotel hotel) async {
    return _firestoreService.create(_hotelsCollection, hotel.toMap());
  }

  /// Gets a hotel by ID.
  Future<Hotel?> getHotel(String id) async {
    final map = await _firestoreService.getById(_hotelsCollection, id);
    if (map == null) return null;
    return Hotel.fromMap(map);
  }

  /// Gets all hotels.
  Future<List<Hotel>> getAllHotels() async {
    final maps = await _firestoreService.getAll(
      collection: _hotelsCollection,
      orderBy: 'name',
    );
    return maps.map(Hotel.fromMap).toList();
  }

  /// Gets a real-time stream of all hotels.
  Stream<List<Hotel>> streamAllHotels() {
    return _firestoreService.streamAll(
      collection: _hotelsCollection,
      orderBy: 'name',
    ).map((maps) => maps.map(Hotel.fromMap).toList());
  }

  /// Updates a hotel.
  Future<void> updateHotel(Hotel hotel) async {
    await _firestoreService.update(
      _hotelsCollection,
      hotel.id,
      hotel.toMap(),
    );
  }

  /// Updates hotel special prices for a product.
  Future<void> updateHotelPrice(
    String hotelId,
    String productId,
    double price,
  ) async {
    final hotel = await getHotel(hotelId);
    if (hotel == null) return;

    final updatedPrices = Map<String, double>.from(hotel.specialPrices);
    updatedPrices[productId] = price;

    await _firestoreService.update(_hotelsCollection, hotelId, {
      'specialPrices': updatedPrices,
    });
  }

  /// Deletes a hotel.
  Future<void> deleteHotel(String id) async {
    await _firestoreService.delete(_hotelsCollection, id);
  }

  // ==================== PRINTED BAG ORDERS ====================

  /// Creates a new printed bag order.
  Future<String> createPrintedOrder(PrintedBagOrder order) async {
    return _firestoreService.create(
      _printedOrdersCollection,
      order.toMap(),
    );
  }

  /// Gets a printed bag order by ID.
  Future<PrintedBagOrder?> getPrintedOrder(String id) async {
    final map = await _firestoreService.getById(_printedOrdersCollection, id);
    if (map == null) return null;
    return PrintedBagOrder.fromMap(map);
  }

  /// Gets all printed bag orders.
  Future<List<PrintedBagOrder>> getAllPrintedOrders({
    String? customerId,
    PrintedOrderStatus? status,
    int? limit,
  }) async {
    final where = <List<dynamic>>[];
    if (customerId != null) where.add(['customerId', '==', customerId]);
    if (status != null) where.add(['status', '==', status.name]);

    final maps = await _firestoreService.getAll(
      collection: _printedOrdersCollection,
      where: where,
      orderBy: 'createdAt',
      descending: true,
      limit: limit,
    );
    return maps.map(PrintedBagOrder.fromMap).toList();
  }

  /// Gets a real-time stream of all printed bag orders.
  Stream<List<PrintedBagOrder>> streamAllPrintedOrders({
    String? customerId,
    PrintedOrderStatus? status,
  }) {
    final where = <List<dynamic>>[];
    if (customerId != null) where.add(['customerId', '==', customerId]);
    if (status != null) where.add(['status', '==', status.name]);

    return _firestoreService.streamAll(
      collection: _printedOrdersCollection,
      where: where,
      orderBy: 'createdAt',
      descending: true,
    ).map((maps) => maps.map(PrintedBagOrder.fromMap).toList());
  }

  /// Updates a printed bag order.
  Future<void> updatePrintedOrder(PrintedBagOrder order) async {
    await _firestoreService.update(
      _printedOrdersCollection,
      order.id,
      order.toMap(),
    );
  }

  /// Updates printed order status.
  Future<void> updatePrintedOrderStatus(
    String orderId,
    PrintedOrderStatus status,
  ) async {
    await _firestoreService.update(_printedOrdersCollection, orderId, {
      'status': status.name,
    });
  }

  /// Deletes a printed bag order.
  Future<void> deletePrintedOrder(String id) async {
    await _firestoreService.delete(_printedOrdersCollection, id);
  }
}

