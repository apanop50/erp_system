/// Sales Invoice Model
///
/// Represents a sales invoice in the ERP system.
/// Contains customer info, products, quantities, pricing, tax, and payment details.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

/// Sales invoice model.
class SalesInvoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final String customerName;
  final String? salesRepId;
  final String? salesRepName;
  final List<InvoiceItem> items;
  double subtotal;
  double discount;
  double taxPercentage;
  double taxAmount;
  double grandTotal;
  double totalCost;
  double profit;
  double paidAmount;
  double remainingBalance;
  InvoiceStatus status;
  final String? notes;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String? pdfUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  SalesInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerName,
    this.salesRepId,
    this.salesRepName,
    required this.items,
    this.subtotal = 0,
    this.discount = 0,
    this.taxPercentage = 0,
    this.taxAmount = 0,
    this.grandTotal = 0,
    this.totalCost = 0,
    this.profit = 0,
    this.paidAmount = 0,
    this.remainingBalance = 0,
    this.status = InvoiceStatus.unpaid,
    this.notes,
    required this.invoiceDate,
    this.dueDate,
    this.pdfUrl,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory SalesInvoice.fromMap(Map<String, dynamic> map) {
    return SalesInvoice(
      id: map['id'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      salesRepId: map['salesId'] as String?,
      salesRepName: map['salesName'] as String?,
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          _buildItemsFromQtyMap(map['qtyByProduct'] as Map<String, dynamic>?),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      taxPercentage: (map['taxPercentage'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (map['total'] as num?)?.toDouble() ?? 0,
      totalCost: (map['costTotal'] as num?)?.toDouble() ?? 0,
      profit: (map['profit'] as num?)?.toDouble() ?? 0,
      paidAmount: (map['paid'] as num?)?.toDouble() ?? 0,
      remainingBalance: (map['remaining'] as num?)?.toDouble() ??
          ((map['total'] as num?)?.toDouble() ?? 0) -
              ((map['paid'] as num?)?.toDouble() ?? 0),
      status: InvoiceStatus.values.firstWhere(
        (s) => s.name == map['status'] || s.name == map['cancelStatus'],
        orElse: () {
          final remaining = (map['remaining'] as num?)?.toDouble() ?? 0;
          final total = (map['total'] as num?)?.toDouble() ?? 0;
          final paid = (map['paid'] as num?)?.toDouble() ?? 0;
          if (map['status'] == 'cancelled' ||
              map['cancelStatus'] == 'cancelled') {
            return InvoiceStatus.cancelled;
          }
          return paid >= total && remaining <= 0
              ? InvoiceStatus.paid
              : paid > 0
                  ? InvoiceStatus.partiallyPaid
                  : InvoiceStatus.unpaid;
        },
      ),
      notes: map['notes'] as String?,
      invoiceDate: (map['date'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      pdfUrl: map['pdfUrl'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'salesId': salesRepId,
      'salesName': salesRepName,
      'items': items.map((e) => e.toMap()).toList(),
      'qtyByProduct': {for (final item in items) item.productId ?? item.id: item.quantity},
      'subtotal': subtotal,
      'discount': discount,
      'total': grandTotal,
      'paid': paidAmount,
      'remaining': remainingBalance,
      'profit': profit,
      'totalCost': totalCost,
      'status': status.name,
      'cancelStatus': status == InvoiceStatus.cancelled ? 'cancelled' : 'none',
      'notes': notes,
      'date': Timestamp.fromDate(invoiceDate),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'salesEmail': '',
      'warehouseId': '',
      'warehouseName': '',
      'itemsCount': items.length,
      'itemsReady': true,
      'stockDeducted': true,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  SalesInvoice copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    String? customerName,
    String? salesRepId,
    String? salesRepName,
    List<InvoiceItem>? items,
    double? subtotal,
    double? discount,
    double? taxPercentage,
    double? taxAmount,
    double? grandTotal,
    double? totalCost,
    double? profit,
    double? paidAmount,
    double? remainingBalance,
    InvoiceStatus? status,
    String? notes,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? pdfUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return SalesInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      salesRepId: salesRepId ?? this.salesRepId,
      salesRepName: salesRepName ?? this.salesRepName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      totalCost: totalCost ?? this.totalCost,
      profit: profit ?? this.profit,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Calculates the invoice totals from items.
  void calculateTotals() {
    subtotal = items.fold(0, (sum, item) => sum + item.total);
    totalCost = items.fold(0, (sum, item) => sum + item.costPrice * item.quantity);
    final afterDiscount = subtotal - discount;
    taxAmount = afterDiscount * (taxPercentage / 100);
    grandTotal = afterDiscount + taxAmount;
    profit = afterDiscount - totalCost;
    remainingBalance = grandTotal - paidAmount;
  }

  /// Returns true if the invoice is fully paid.
  bool get isPaid => remainingBalance <= 0 && paidAmount >= grandTotal;

  /// Builds invoice line items from the Firestore `qtyByProduct` map
  /// (productId -> quantity), since real invoices store quantities per product.
  static List<InvoiceItem> _buildItemsFromQtyMap(Map<String, dynamic>? qtyMap) {
    return qtyMap == null
        ? <InvoiceItem>[]
        : qtyMap.entries.map((e) {
            return InvoiceItem(
              id: e.key,
              productId: e.key,
              productName: e.key,
              quantity: (e.value as num).toDouble(),
            );
          }).toList();
  }
}

/// Invoice line item model.
class InvoiceItem {
  final String id;
  final String? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double discount;
  double total;

  InvoiceItem({
    required this.id,
    this.productId,
    required this.productName,
    this.quantity = 1,
    this.unitPrice = 0,
    this.costPrice = 0,
    this.discount = 0,
    this.total = 0,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as String? ?? (map['productId'] as String? ?? ''),
      productId: map['productId'] as String?,
      productName: (map['name'] ?? map['productName']) as String? ?? '',
      quantity: ((map['qty'] ?? map['quantity']) as num?)?.toDouble() ?? 1,
      unitPrice: ((map['buyPrice'] ?? map['unitPrice']) as num?)?.toDouble() ?? 0,
      costPrice: ((map['costPrice'] ?? map['purchasePrice']) as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      total: ((map['lineTotal'] ?? map['total']) as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'costPrice': costPrice,
      'discount': discount,
      'total': total,
    };
  }

  /// Calculates the line total.
  void calculateTotal() {
    total = (quantity * unitPrice) - discount;
  }
}

/// Purchase invoice model.
class PurchaseInvoice {
  final String id;
  final String invoiceNumber;
  final String supplierId;
  final String supplierName;
  final List<InvoiceItem> items;
  double subtotal;
  final double discount;
  final double taxAmount;
  double grandTotal;
  final double paidAmount;
  double remainingBalance;
  final String status;
  final String? notes;
  final DateTime invoiceDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  PurchaseInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    this.subtotal = 0,
    this.discount = 0,
    this.taxAmount = 0,
    this.grandTotal = 0,
    this.paidAmount = 0,
    this.remainingBalance = 0,
    this.status = 'unpaid',
    this.notes,
    required this.invoiceDate,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String? ?? '',
      supplierName: (map['supplierName'] ?? map['name']) as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => InvoiceItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0,
      grandTotal: (map['total'] as num?)?.toDouble() ??
          (map['lineTotal'] as num?)?.toDouble() ??
          0,
      paidAmount: (map['paid'] as num?)?.toDouble() ?? 0,
      remainingBalance: (map['remaining'] as num?)?.toDouble() ?? 0,
      status: map['status'] as String? ?? 'unpaid',
      notes: (map['notes'] ?? map['note']) as String?,
      invoiceDate: (map['date'] as Timestamp?)?.toDate() ??
          (map['invoiceDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'taxAmount': taxAmount,
      'total': grandTotal,
      'paid': paidAmount,
      'remaining': remainingBalance,
      'status': status,
      'notes': notes,
      'date': Timestamp.fromDate(invoiceDate),
      'warehouseId': '',
      'supplierPhone': '',
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }

  PurchaseInvoice copyWith({
    String? id,
    String? invoiceNumber,
    String? supplierId,
    String? supplierName,
    List<InvoiceItem>? items,
    double? subtotal,
    double? discount,
    double? taxAmount,
    double? grandTotal,
    double? paidAmount,
    double? remainingBalance,
    String? status,
    String? notes,
    DateTime? invoiceDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return PurchaseInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      taxAmount: taxAmount ?? this.taxAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Recomputes totals from the line items.
  void calculateTotals() {
    for (final item in items) {
      item.calculateTotal();
    }
    subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    grandTotal = subtotal - discount + taxAmount;
    remainingBalance = grandTotal - paidAmount;
  }
}

/// Expense model.
class Expense {
  final String id;
  final ExpenseCategory category;
  final String? description;
  final double amount;
  final DateTime expenseDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const Expense({
    required this.id,
    required this.category,
    this.description,
    required this.amount,
    required this.expenseDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String? ?? '',
      category: ExpenseCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ExpenseCategory.miscellaneous,
      ),
      description: (map['title'] ?? map['description']) as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      expenseDate: (map['date'] as Timestamp?)?.toDate() ??
          (map['expenseDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      notes: (map['notes'] ?? map['note']) as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.name,
      'title': description,
      'description': description,
      'amount': amount,
      'date': Timestamp.fromDate(expenseDate),
      'expenseDate': Timestamp.fromDate(expenseDate),
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }
}

/// Sales representative model.
class SalesRepresentative {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? photoUrl;
  final String? address;
  final double commissionRate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SalesRepresentative({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.photoUrl,
    this.address,
    this.commissionRate = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory SalesRepresentative.fromMap(Map<String, dynamic> map) {
    return SalesRepresentative(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      photoUrl: map['photoUrl'] as String?,
      address: map['address'] as String?,
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'photoUrl': photoUrl,
      'address': address,
      'commissionRate': commissionRate,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// Hotel model with special pricing.
class Hotel {
  final String id;
  final String customerId;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final Map<String, double> specialPrices; // productId -> price
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Hotel({
    required this.id,
    required this.customerId,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.specialPrices = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory Hotel.fromMap(Map<String, dynamic> map) {
    final pricesRaw = map['specialPrices'] as Map<String, dynamic>?;
    return Hotel(
      id: map['id'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      contactPerson: map['contactPerson'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      specialPrices: pricesRaw?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ) ??
          {},
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'specialPrices': specialPrices,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// Printed bag order model.
class PrintedBagOrder {
  final String id;
  final String customerId;
  final String customerName;
  final String productName;
  final String? logoUrl;
  final String? designUrl;
  final String? printingColors;
  final String? printingSize;
  final int printingQuantity;
  final String? printingNotes;
  final PrintedOrderStatus status;
  final double unitPrice;
  final double totalPrice;
  final DateTime? deliveryDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const PrintedBagOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.productName,
    this.logoUrl,
    this.designUrl,
    this.printingColors,
    this.printingSize,
    this.printingQuantity = 0,
    this.printingNotes,
    this.status = PrintedOrderStatus.newOrder,
    this.unitPrice = 0,
    this.totalPrice = 0,
    this.deliveryDate,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory PrintedBagOrder.fromMap(Map<String, dynamic> map) {
    return PrintedBagOrder(
      id: map['id'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      logoUrl: map['logoUrl'] as String?,
      designUrl: map['designUrl'] as String?,
      printingColors: map['printingColors'] as String?,
      printingSize: map['printingSize'] as String?,
      printingQuantity: (map['printingQuantity'] as num?)?.toInt() ?? 0,
      printingNotes: map['printingNotes'] as String?,
      status: PrintedOrderStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PrintedOrderStatus.newOrder,
      ),
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
      deliveryDate: (map['deliveryDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'productName': productName,
      'logoUrl': logoUrl,
      'designUrl': designUrl,
      'printingColors': printingColors,
      'printingSize': printingSize,
      'printingQuantity': printingQuantity,
      'printingNotes': printingNotes,
      'status': status.name,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'deliveryDate': deliveryDate != null
          ? Timestamp.fromDate(deliveryDate!)
          : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
    };
  }
}
