/// Finance Models
///
/// Accounting primitives for the ERP system:
/// - رأس المال (Capital): fixed initial capital.
/// - الأرباح (Profit): separate account that grows from sales.
/// - حركة الشركاء (Partner transactions): money added/withdrawn by partners.
///
/// Design rule: capital stays fixed; profit accumulates separately so money is
/// never double-counted in capital.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of a ledger entry.
enum LedgerType {
  initialCapital('initial_capital', 'رأس المال'),
  partnerAdd('partner_add', 'إيداع شريك'),
  partnerWithdraw('partner_withdraw', 'سحب شريك'),
  purchase('purchase', 'مشتريات'),
  sale('sale', 'مبيعات'),
  saleProfit('sale_profit', 'ربح مبيعات'),
  expense('expense', 'مصروف'),
  adjustment('adjustment', 'تسوية');

  final String name;
  final String ar;
  const LedgerType(this.name, this.ar);
}

/// A single ledger / journal entry used to compute capital & profit.
class LedgerEntry {
  final String id;
  final LedgerType type;
  final double amount;
  final DateTime date;
  final String? description;
  final String? relatedId; // partnerId, invoiceId, etc.
  final DateTime? createdAt;

  const LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.description,
    this.relatedId,
    this.createdAt,
  });

  factory LedgerEntry.fromMap(Map<String, dynamic> map) {
    return LedgerEntry(
      id: map['id'] as String? ?? '',
      type: LedgerType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => LedgerType.adjustment,
      ),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] as String?,
      relatedId: map['relatedId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
      'relatedId': relatedId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

/// Money movement on a partner account (حركة الشريك).
class PartnerTransaction {
  final String id;
  final String partnerId;
  final String type; // 'add' | 'withdraw'
  final double amount;
  final DateTime date;
  final String? notes;
  final DateTime? createdAt;

  const PartnerTransaction({
    required this.id,
    required this.partnerId,
    this.type = 'add',
    required this.amount,
    required this.date,
    this.notes,
    this.createdAt,
  });

  factory PartnerTransaction.fromMap(Map<String, dynamic> map) {
    return PartnerTransaction(
      id: map['id'] as String? ?? '',
      partnerId: map['partnerId'] as String? ?? '',
      type: map['type'] as String? ?? 'add',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'partnerId': partnerId,
      'type': type,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}

/// Aggregated accounting summary.
class FinanceSummary {
  final double capital; // fixed initial capital
  final double partnerBalance; // total money partners have in the business
  final double purchases; // total cost of goods purchased
  final double sales; // total revenue
  final double profit; // accumulated profit (sales - cost of sold goods)
  final double expenses;

  const FinanceSummary({
    this.capital = 0,
    this.partnerBalance = 0,
    this.purchases = 0,
    this.sales = 0,
    this.profit = 0,
    this.expenses = 0,
  });
}