/// Customer Model
///
/// Represents a customer in the ERP system.
/// Customers can be normal, hotels, restaurants, supermarkets, or factories.
/// Each customer has account balance, credit limit, and payment history.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

/// Customer model for the ERP system.
class Customer {
  final String id;
  final String name;
  final String? companyName;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? email;
  final String? taxNumber;
  final CustomerType customerType;
  final double accountBalance;
  final double creditLimit;
  final String? notes;
  final String? logoUrl;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const Customer({
    required this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.whatsapp,
    this.address,
    this.city,
    this.email,
    this.taxNumber,
    this.customerType = CustomerType.normal,
    this.accountBalance = 0,
    this.creditLimit = 0,
    this.notes,
    this.logoUrl,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      companyName: map['companyName'] as String?,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      email: map['email'] as String?,
      taxNumber: map['taxNumber'] as String?,
      customerType: CustomerType.values.firstWhere(
        (t) => t.name == map['customerType'],
        orElse: () => CustomerType.normal,
      ),
      accountBalance: (map['balance'] as num?)?.toDouble() ?? 0,
      creditLimit: (map['creditLimit'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      logoUrl: map['logoUrl'] as String?,
      imageUrl: map['imageUrl'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'salesId': createdBy,
      'customerType': customerType.name,
      'accountBalance': accountBalance,
      'creditLimit': creditLimit,
      'balance': accountBalance,
      'notes': notes,
      'logoUrl': logoUrl,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? companyName,
    String? phone,
    String? whatsapp,
    String? address,
    String? city,
    String? email,
    String? taxNumber,
    CustomerType? customerType,
    double? accountBalance,
    double? creditLimit,
    String? notes,
    String? logoUrl,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      city: city ?? this.city,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      customerType: customerType ?? this.customerType,
      accountBalance: accountBalance ?? this.accountBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      notes: notes ?? this.notes,
      logoUrl: logoUrl ?? this.logoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Returns true if the customer has exceeded their credit limit.
  bool get hasExceededCreditLimit =>
      creditLimit > 0 && accountBalance > creditLimit;

  /// Returns the available credit.
  double get availableCredit =>
      creditLimit > 0 ? creditLimit - accountBalance : 0;
}

/// Payment model for customer payment history.
class Payment {
  final String id;
  final String? invoiceId;
  final String customerId;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  const Payment({
    required this.id,
    this.invoiceId,
    required this.customerId,
    required this.amount,
    this.paymentMethod = 'cash',
    required this.paymentDate,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String? ?? '',
      invoiceId: map['invoiceId'] as String?,
      customerId: map['customerId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      paymentDate: (map['date'] as Timestamp?)?.toDate() ??
          (map['paymentDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'customerId': customerId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'type': paymentMethod,
      'date': Timestamp.fromDate(paymentDate),
      'salesId': createdBy,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'createdBy': createdBy,
    };
  }
}

/// Account statement entry model.
class AccountStatementEntry {
  final String id;
  final String type; // 'invoice', 'payment', 'adjustment'
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final DateTime date;

  const AccountStatementEntry({
    required this.id,
    required this.type,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    required this.balance,
    required this.date,
  });

  factory AccountStatementEntry.fromMap(Map<String, dynamic> map) {
    return AccountStatementEntry(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      description: map['description'] as String? ?? '',
      debit: (map['debit'] as num?)?.toDouble() ?? 0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

