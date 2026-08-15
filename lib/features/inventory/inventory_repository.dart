/// Inventory Models & Repository
///
/// Provides access to the `warehouses` and `tenants` Firestore collections.
/// Kept minimal and self-contained to expose the real Firebase data in the app.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firestore_service.dart';

/// Warehouse model (collection `warehouses`).
class Warehouse {
  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Warehouse({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    return Warehouse(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}

/// Tenant model (collection `tenants`).
class Tenant {
  final String id;
  final String name;
  final double capital;
  final double percentage;

  const Tenant({
    required this.id,
    required this.name,
    this.capital = 0,
    this.percentage = 0,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      capital: (map['capital'] as num?)?.toDouble() ?? 0,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'capital': capital,
      'percentage': percentage,
    };
  }
}

/// Repository for warehouses and tenants.
class InventoryRepository {
  final FirestoreService _firestoreService;
  static const String _warehouses = 'warehouses';
  static const String _tenants = 'tenants';
  static const String _cancelRequests = 'cancel_requests';

  InventoryRepository(this._firestoreService);

  /// Gets a real-time list of warehouses.
  Stream<List<Warehouse>> streamWarehouses() {
    return _firestoreService
        .streamAll(collection: _warehouses, orderBy: 'name')
        .map((maps) => maps.map(Warehouse.fromMap).toList());
  }

  /// Gets a real-time list of tenants.
  Stream<List<Tenant>> streamTenants() {
    return _firestoreService
        .streamAll(collection: _tenants, orderBy: 'name')
        .map((maps) => maps.map(Tenant.fromMap).toList());
  }

  /// Gets a real-time list of cancel requests.
  Stream<List<CancelRequest>> streamCancelRequests() {
    return _firestoreService
        .streamAll(
          collection: _cancelRequests,
          orderBy: 'createdAt',
          descending: true,
        )
        .map((maps) => maps.map(CancelRequest.fromMap).toList());
  }
}

/// Provider for the InventoryRepository instance.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(FirestoreService());
});

/// Provider for the warehouses stream.
final warehousesStreamProvider = StreamProvider<List<Warehouse>>((ref) {
  return ref.watch(inventoryRepositoryProvider).streamWarehouses();
});

/// Provider for the tenants stream.
final tenantsStreamProvider = StreamProvider<List<Tenant>>((ref) {
  return ref.watch(inventoryRepositoryProvider).streamTenants();
});

/// Cancel request model (collection `cancel_requests`).
class CancelRequest {
  final String id;
  final String? customerId;
  final String? customerName;
  final String? invoiceId;
  final String? status;
  final String? reason;
  final DateTime? createdAt;

  const CancelRequest({
    required this.id,
    this.customerId,
    this.customerName,
    this.invoiceId,
    this.status,
    this.reason,
    this.createdAt,
  });

  factory CancelRequest.fromMap(Map<String, dynamic> map) {
    return CancelRequest(
      id: map['id'] as String? ?? '',
      customerId: map['customerId'] as String?,
      customerName: map['customerName'] as String?,
      invoiceId: map['invoiceId'] as String?,
      status: map['status'] as String?,
      reason: (map['reason'] ?? map['notes']) as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Provider for the cancel requests stream.
final cancelRequestsStreamProvider = StreamProvider<List<CancelRequest>>((ref) {
  return ref.watch(inventoryRepositoryProvider).streamCancelRequests();
});
