/// Product Model
///
/// Represents a product in the ERP system.
/// Products are packaging items like garbage bags, food bags, plastic rolls, etc.
/// Each product has multiple pricing tiers: cost, selling, hotel, and wholesale prices.
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';

/// Product model for the ERP system.
class Product {
  final String id;
  final String? imageUrl;
  final String name;
  final String? nameAr;
  final String? nameEn;
  final String? barcode;
  final String? internalCode;
  final String? categoryId;
  final String? categoryName;
  final String? supplierId;
  final String? supplierName;
  final double costPrice;
  final double sellingPrice;
  final double hotelPrice;
  final double wholesalePrice;
  final String unit;
  final double currentStock;
  final double minimumStock;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const Product({
    required this.id,
    this.imageUrl,
    required this.name,
    this.nameAr,
    this.nameEn,
    this.barcode,
    this.internalCode,
    this.categoryId,
    this.categoryName,
    this.supplierId,
    this.supplierName,
    this.costPrice = 0,
    this.sellingPrice = 0,
    this.hotelPrice = 0,
    this.wholesalePrice = 0,
    this.unit = 'piece',
    this.currentStock = 0,
    this.minimumStock = 0,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  /// Creates a Product from a Firestore document map.
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      name: map['name'] as String? ?? '',
      nameAr: map['nameAr'] as String?,
      nameEn: map['nameEn'] as String?,
      barcode: map['barcode'] as String?,
      internalCode: map['internalCode'] as String?,
      categoryId: map['categoryId'] as String?,
      categoryName: map['categoryName'] as String?,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      costPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (map['sellPrice'] as num?)?.toDouble() ?? 0,
      hotelPrice: (map['hotelPrice'] as num?)?.toDouble() ?? 0,
      wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'piece',
      currentStock: (map['stock'] as num?)?.toDouble() ?? 0,
      minimumStock: (map['minimumStock'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  /// Converts the Product to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'name': name,
      'nameAr': nameAr,
      'nameEn': nameEn,
      'barcode': barcode,
      'internalCode': internalCode,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'hotelPrice': hotelPrice,
      'wholesalePrice': wholesalePrice,
      'unit': unit,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      // Real Firebase (products) field aliases
      'buyPrice': costPrice,
      'sellPrice': sellingPrice,
      'stock': currentStock,
    };
  }

  /// Creates a copy of this Product with the given fields replaced.
  Product copyWith({
    String? id,
    String? imageUrl,
    String? name,
    String? nameAr,
    String? nameEn,
    String? barcode,
    String? internalCode,
    String? categoryId,
    String? categoryName,
    String? supplierId,
    String? supplierName,
    double? costPrice,
    double? sellingPrice,
    double? hotelPrice,
    double? wholesalePrice,
    String? unit,
    double? currentStock,
    double? minimumStock,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Product(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      barcode: barcode ?? this.barcode,
      internalCode: internalCode ?? this.internalCode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      hotelPrice: hotelPrice ?? this.hotelPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Returns true if the product stock is low (at or below minimum).
  bool get isLowStock => currentStock <= minimumStock;

  /// Returns the profit margin for this product.
  double get profitMargin => sellingPrice - costPrice;

  /// Returns the profit margin percentage.
  double get profitMarginPercentage =>
      costPrice > 0 ? (profitMargin / costPrice) * 100 : 0;
}

/// Category model for product categorization.
class Category {
  final String id;
  final String name;
  final String? nameAr;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.nameAr,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      nameAr: map['nameAr'] as String?,
      description: map['description'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameAr': nameAr,
      'description': description,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// Supplier model for purchase management.
class Supplier {
  final String id;
  final String name;
  final String? companyName;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? city;
  final String? email;
  final String? taxNumber;
  final double balance;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.companyName,
    this.phone,
    this.whatsapp,
    this.address,
    this.city,
    this.email,
    this.taxNumber,
    this.balance = 0,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      companyName: map['companyName'] as String?,
      phone: map['phone'] as String?,
      whatsapp: map['whatsapp'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      email: map['email'] as String?,
      taxNumber: map['taxNumber'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'companyName': companyName,
      'phone': phone,
      'whatsapp': whatsapp,
      'address': address,
      'city': city,
      'email': email,
      'taxNumber': taxNumber,
      'balance': balance,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? companyName,
    String? phone,
    String? whatsapp,
    String? address,
    String? city,
    String? email,
    String? taxNumber,
    double? balance,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      city: city ?? this.city,
      email: email ?? this.email,
      taxNumber: taxNumber ?? this.taxNumber,
      balance: balance ?? this.balance,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
