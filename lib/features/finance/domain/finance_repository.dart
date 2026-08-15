/// Finance Repository
///
/// Manages ledger entries, partner (شريك) accounts, and partner transactions.
/// Writes are saved locally first (via [LocalStore]) then synced to Firestore
/// so that saving never hangs when offline.
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/local_store.dart';
import '../../products/domain/product_model.dart' show Supplier;
import '../../inventory/inventory_repository.dart' show Tenant;
import '../../sales/domain/sales_model.dart';
import 'finance_model.dart';

/// Repository for finance/accounting data.
class FinanceRepository {
  final FirestoreService _firestore;
  final Uuid _uuid = const Uuid();

  static const String _tenants = 'tenants';
  static const String _suppliers = 'suppliers';
  static const String _partnerTxn = 'partner_transactions';

  FinanceRepository(this._firestore);

  // ==================== PARTNERS (الشركاء) ====================

  /// Creates a partner (tenant) with an initial capital.
  Future<String> createPartner({
    required String name,
    double capital = 0,
    double percentage = 0,
  }) async {
    final id = _uuid.v4();
    final map = {
      'id': id,
      'name': name,
      'capital': capital,
      'percentage': percentage,
      'isActive': true,
    };
    LocalStore.put(LocalStore.partnerPrefix, id, map);
    try {
      await _firestore.createWithId(_tenants, id, map);
    } catch (_) {
      /* local backup saved */
    }
    if (capital > 0) {
      await addPartnerMoney(
        partnerId: id,
        amount: capital,
        notes: 'رأس مال شريك',
      );
    }
    return id;
  }

  /// Updates a partner.
  Future<void> updatePartner({
    required String id,
    required String name,
    double capital = 0,
    double percentage = 0,
  }) async {
    final map = {
      'id': id,
      'name': name,
      'capital': capital,
      'percentage': percentage,
      'isActive': true,
    };
    LocalStore.put(LocalStore.partnerPrefix, id, map);
    try {
      await _firestore.createWithId(_tenants, id, map);
    } catch (_) {
      /* local backup saved */
    }
  }

  /// Lists partners from Firestore, falling back to local.
  Future<List<Tenant>> getPartners() async {
    try {
      final maps = await _firestore.getAll(
        collection: _tenants,
        orderBy: 'name',
      );
      return maps.map(Tenant.fromMap).toList();
    } catch (_) {
      return LocalStore.getAll(LocalStore.partnerPrefix)
          .where((m) => m['name'] != null && m['isActive'] != false)
          .map(Tenant.fromMap)
          .toList();
    }
  }

  // ==================== PARTNER TRANSACTIONS (حركة الشركاء) ====================

  /// Adds money to a partner's account (إيداع). Creates a ledger entry and a
  /// partner transaction, both saved locally + Firestore.
  Future<void> addPartnerMoney({
    required String partnerId,
    required double amount,
    String? notes,
  }) async {
    await _recordPartnerTxn(
      partnerId: partnerId,
      type: 'add',
      amount: amount,
      notes: notes,
    );
  }

  /// Withdraws money from a partner's account (سحب).
  Future<void> withdrawPartnerMoney({
    required String partnerId,
    required double amount,
    String? notes,
  }) async {
    await _recordPartnerTxn(
      partnerId: partnerId,
      type: 'withdraw',
      amount: amount,
      notes: notes,
    );
  }

  Future<void> _recordPartnerTxn({
    required String partnerId,
    required String type,
    required double amount,
    String? notes,
  }) async {
    final txnId = _uuid.v4();
    final txn = PartnerTransaction(
      id: txnId,
      partnerId: partnerId,
      type: type,
      amount: amount,
      date: DateTime.now(),
      notes: notes,
      createdAt: DateTime.now(),
    );
    LocalStore.put(LocalStore.partnerTxnPrefix, txnId, txn.toMap());

    final ledgerId = _uuid.v4();
    final entry = LedgerEntry(
      id: ledgerId,
      type: type == 'add' ? LedgerType.partnerAdd : LedgerType.partnerWithdraw,
      amount: amount,
      date: DateTime.now(),
      description: notes,
      relatedId: partnerId,
      createdAt: DateTime.now(),
    );
    LocalStore.put(LocalStore.financePrefix, ledgerId, entry.toMap());

    try {
      await _firestore.createWithId(_partnerTxn, txnId, txn.toMap());
      await _firestore.createWithId('ledger', ledgerId, entry.toMap());
    } catch (_) {
      /* local backups saved */
    }
  }

  /// Lists partner transactions for a partner.
  Future<List<PartnerTransaction>> getPartnerTransactions(
    String partnerId,
  ) async {
    try {
      final maps = await _firestore.getAll(
        collection: _partnerTxn,
        where: [
          ['partnerId', '==', partnerId],
        ],
        orderBy: 'date',
        descending: true,
      );
      return maps.map(PartnerTransaction.fromMap).toList();
    } catch (_) {
      return LocalStore.getAll(LocalStore.partnerTxnPrefix)
          .where((m) => m['partnerId'] == partnerId)
          .map(PartnerTransaction.fromMap)
          .toList();
    }
  }

  // ==================== SUPPLIERS (الموردين) ====================

  /// Creates a supplier.
  Future<String> createSupplier(Supplier supplier) async {
    final id = supplier.id.isEmpty ? _uuid.v4() : supplier.id;
    final safe = supplier.copyWith(id: id);
    LocalStore.put(LocalStore.supplierPrefix, id, safe.toMap());
    try {
      await _firestore.createWithId(_suppliers, id, safe.toMap());
    } catch (_) {
      /* local backup saved */
    }
    return id;
  }

  /// Updates a supplier.
  Future<void> updateSupplier(Supplier supplier) async {
    LocalStore.put(LocalStore.supplierPrefix, supplier.id, supplier.toMap());
    try {
      await _firestore.createWithId(_suppliers, supplier.id, supplier.toMap());
    } catch (_) {
      /* local backup saved */
    }
  }

  // ==================== SUMMARY ====================

  /// Computes an aggregate finance summary.
  ///
  /// Business rule requested by the user:
  ///   الأرباح = إجمالي البيع - إجمالي الشراء
  ///
  /// Expenses are kept in a separate field so the UI can show them separately
  /// or compute net profit when needed.
  Future<FinanceSummary> computeSummary() async {
    final invoices = await _getSalesInvoices();
    final purchasesInvoices = await _getPurchaseInvoices();
    final expensesList = await _getExpenses();

    final sales = invoices
        .where((i) => i.status != InvoiceStatus.cancelled)
        .fold<double>(0, (sum, invoice) => sum + invoice.grandTotal);
    final purchases = purchasesInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.grandTotal,
    );
    final expenses = expensesList.fold<double>(0, (sum, e) => sum + e.amount);

    final entries = LocalStore.getAll(LocalStore.financePrefix);
    final txns = LocalStore.getAll(LocalStore.partnerTxnPrefix);

    double capital = 0;

    for (final e in entries) {
      final t = LedgerEntry.fromMap(e).type;
      final amt = (e['amount'] as num?)?.toDouble() ?? 0;
      switch (t) {
        case LedgerType.initialCapital:
          capital += amt;
          break;
        case LedgerType.partnerAdd:
          capital += amt;
          break;
        case LedgerType.partnerWithdraw:
          capital -= amt;
          break;
        case LedgerType.purchase:
        case LedgerType.sale:
        case LedgerType.saleProfit:
        case LedgerType.expense:
        case LedgerType.adjustment:
          break;
      }
    }

    double partnerBalance = 0;
    for (final t in txns) {
      final m = PartnerTransaction.fromMap(t);
      partnerBalance += m.type == 'add' ? m.amount : -m.amount;
    }

    return FinanceSummary(
      capital: capital > 0 ? capital : 0,
      partnerBalance: partnerBalance,
      purchases: purchases,
      sales: sales,
      profit: sales - purchases,
      expenses: expenses,
    );
  }

  Future<List<SalesInvoice>> _getSalesInvoices() async {
    try {
      final maps = await _firestore.getAll(
        collection: 'invoices',
        orderBy: 'date',
        descending: true,
        limit: 1000,
      );
      return maps.map(SalesInvoice.fromMap).toList();
    } catch (_) {
      return LocalStore.getAll(
        LocalStore.invoicePrefix,
      ).map(SalesInvoice.fromMap).toList();
    }
  }

  Future<List<PurchaseInvoice>> _getPurchaseInvoices() async {
    try {
      final maps = await _firestore.getAll(
        collection: 'purchase_invoices',
        orderBy: 'date',
        descending: true,
        limit: 1000,
      );
      return maps.map(PurchaseInvoice.fromMap).toList();
    } catch (_) {
      return LocalStore.getAll(
        LocalStore.purchasePrefix,
      ).map(PurchaseInvoice.fromMap).toList();
    }
  }

  Future<List<Expense>> _getExpenses() async {
    try {
      final maps = await _firestore.getAll(
        collection: 'expenses',
        orderBy: 'expenseDate',
        descending: true,
        limit: 1000,
      );
      return maps.map(Expense.fromMap).toList();
    } catch (_) {
      return LocalStore.getAll(
        LocalStore.expensePrefix,
      ).map(Expense.fromMap).toList();
    }
  }
}
