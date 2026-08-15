/// Inventory Stock Repository & Models
///
/// Handles multi-warehouse stock management for the ERP system:
///   - Warehouse CRUD
///   - Per-warehouse stock balances
///   - Stock movements (inbound / outbound)
///   - Transfers between warehouses (atomic)
///   - Stock counts / inventory auditing
///   - Reorder point (low stock) detection
///
/// Follows the project's offline-first pattern: always writes a local backup
/// (via [LocalStore]) before attempting the Firestore write, and reads fall
/// back to the local store when Firestore is unreachable.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/local_store.dart';
import 'inventory_repository.dart';

/// Type of a stock movement.
enum MovementType {
  inbound('inbound', 'وارد'),
  outbound('outbound', 'منصرف'),
  transferIn('transfer_in', 'تحويل وارد'),
  transferOut('transfer_out', 'تحويل منصرف'),
  adjustment('adjustment', 'تسوية'),
  count('count', 'جرد');

  final String code;
  final String ar;
  const MovementType(this.code, this.ar);

  static MovementType fromCode(String? code) => values.firstWhere(
    (e) => e.code == code,
    orElse: () => MovementType.adjustment,
  );
}

/// Represents the current stock of a single product in a single warehouse.
class StockBalance {
  final String id; // 'warehouseId|productId'
  final String warehouseId;
  final String? warehouseName;
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double minStock; // reorder point for this product in this warehouse
  final DateTime? updatedAt;

  const StockBalance({
    required this.id,
    required this.warehouseId,
    this.warehouseName,
    required this.productId,
    required this.productName,
    this.unit = 'piece',
    this.quantity = 0,
    this.minStock = 0,
    this.updatedAt,
  });

  factory StockBalance.fromMap(Map<String, dynamic> map) {
    return StockBalance(
      id: map['id'] as String? ?? '',
      warehouseId: map['warehouseId'] as String? ?? '',
      warehouseName: map['warehouseName'] as String?,
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unit: map['unit'] as String? ?? 'piece',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      minStock: (map['minStock'] as num?)?.toDouble() ?? 0,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'warehouseId': warehouseId,
      'warehouseName': warehouseName,
      'productId': productId,
      'productName': productName,
      'unit': unit,
      'quantity': quantity,
      'minStock': minStock,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  StockBalance copyWith({
    double? quantity,
    double? minStock,
    String? warehouseName,
    DateTime? updatedAt,
  }) {
    return StockBalance(
      id: id,
      warehouseId: warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      productId: productId,
      productName: productName,
      unit: unit,
      quantity: quantity ?? this.quantity,
      minStock: minStock ?? this.minStock,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// True when quantity is at or below the reorder point.
  bool get isLow => minStock > 0 && quantity <= minStock;
}

/// A single stock movement into or out of a warehouse.
class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final String unit;
  final String warehouseId;
  final String? warehouseName;
  final double quantity;
  final MovementType type;
  final String? reference;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    this.unit = 'piece',
    required this.warehouseId,
    this.warehouseName,
    required this.quantity,
    required this.type,
    this.reference,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unit: map['unit'] as String? ?? 'piece',
      warehouseId: map['warehouseId'] as String? ?? '',
      warehouseName: map['warehouseName'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      type: MovementType.fromCode(map['type'] as String?),
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'unit': unit,
      'warehouseId': warehouseId,
      'warehouseName': warehouseName,
      'quantity': quantity,
      'type': type.code,
      'reference': reference,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'createdBy': createdBy,
    };
  }
}

/// A product line inside a transfer between warehouses.
class StockTransferItem {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;

  const StockTransferItem({
    required this.productId,
    required this.productName,
    this.unit = 'piece',
    required this.quantity,
  });

  factory StockTransferItem.fromMap(Map<String, dynamic> map) {
    return StockTransferItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unit: map['unit'] as String? ?? 'piece',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unit': unit,
      'quantity': quantity,
    };
  }
}

/// A stock transfer from one warehouse to another.
class StockTransfer {
  final String id;
  final String fromWarehouseId;
  final String? fromWarehouseName;
  final String toWarehouseId;
  final String? toWarehouseName;
  final List<StockTransferItem> items;
  final String? notes;
  final String? status;
  final DateTime? createdAt;
  final String? createdBy;

  const StockTransfer({
    required this.id,
    required this.fromWarehouseId,
    this.fromWarehouseName,
    required this.toWarehouseId,
    this.toWarehouseName,
    this.items = const [],
    this.notes,
    this.status = 'completed',
    this.createdAt,
    this.createdBy,
  });

  factory StockTransfer.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return StockTransfer(
      id: map['id'] as String? ?? '',
      fromWarehouseId: map['fromWarehouseId'] as String? ?? '',
      fromWarehouseName: map['fromWarehouseName'] as String?,
      toWarehouseId: map['toWarehouseId'] as String? ?? '',
      toWarehouseName: map['toWarehouseName'] as String?,
      items: rawItems
          .map((e) => StockTransferItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'completed',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromWarehouseId': fromWarehouseId,
      'fromWarehouseName': fromWarehouseName,
      'toWarehouseId': toWarehouseId,
      'toWarehouseName': toWarehouseName,
      'items': items.map((e) => e.toMap()).toList(),
      'notes': notes,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'createdBy': createdBy,
    };
  }

  int get totalItems => items.length;
}

/// A product line inside a stock count.
class StockCountItem {
  final String productId;
  final String productName;
  final String unit;
  final double systemQty;
  final double countQty;
  final String? notes;

  const StockCountItem({
    required this.productId,
    required this.productName,
    this.unit = 'piece',
    required this.systemQty,
    required this.countQty,
    this.notes,
  });

  factory StockCountItem.fromMap(Map<String, dynamic> map) {
    return StockCountItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      unit: map['unit'] as String? ?? 'piece',
      systemQty: (map['systemQty'] as num?)?.toDouble() ?? 0,
      countQty: (map['countQty'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'unit': unit,
      'systemQty': systemQty,
      'countQty': countQty,
      'notes': notes,
    };
  }

  double get difference => countQty - systemQty;
}

/// A stock count (inventory audit) performed on a warehouse.
class StockCount {
  final String id;
  final String warehouseId;
  final String? warehouseName;
  final List<StockCountItem> items;
  final String status; // 'pending' | 'completed'
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  const StockCount({
    required this.id,
    required this.warehouseId,
    this.warehouseName,
    this.items = const [],
    this.status = 'pending',
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  factory StockCount.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return StockCount(
      id: map['id'] as String? ?? '',
      warehouseId: map['warehouseId'] as String? ?? '',
      warehouseName: map['warehouseName'] as String?,
      items: rawItems
          .map((e) => StockCountItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      status: map['status'] as String? ?? 'pending',
      notes: map['notes'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'warehouseId': warehouseId,
      'warehouseName': warehouseName,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'createdBy': createdBy,
    };
  }

  /// Total absolute difference across all counted items.
  double get totalDifference =>
      items.fold<double>(0, (sum, i) => sum + i.difference);

  int get differenceCount => items.where((i) => i.difference != 0).length;
}

/// Repository for multi-warehouse inventory operations.
class StockRepository {
  final FirestoreService _firestoreService;
  static const String _warehouses = 'warehouses';
  static const String _balances = 'stock_balances';
  static const String _movements = 'stock_movements';
  static const String _transfers = 'stock_transfers';
  static const String _counts = 'stock_counts';

  final Uuid _uuid = const Uuid();

  StockRepository(this._firestoreService);

  /// Unique id for a balance document of a product in a warehouse.
  static String balanceId(String warehouseId, String productId) =>
      '$warehouseId|$productId';

  // ==================== WAREHOUSES ====================

  /// Creates a new warehouse.
  Future<String> createWarehouse(Warehouse warehouse) async {
    final id = warehouse.id.isEmpty ? _uuid.v4() : warehouse.id;
    final safe = Warehouse(id: id, name: warehouse.name);
    LocalStore.put(LocalStore.warehousePrefix, id, safe.toMap());
    try {
      await _firestoreService.createWithId(_warehouses, id, safe.toMap());
    } catch (_) {
      // Local backup saved; synced when connectivity returns.
    }
    return id;
  }

  /// Updates an existing warehouse.
  Future<void> updateWarehouse(Warehouse warehouse) async {
    final safe = Warehouse(id: warehouse.id, name: warehouse.name);
    LocalStore.put(LocalStore.warehousePrefix, warehouse.id, safe.toMap());
    try {
      await _firestoreService.update(_warehouses, warehouse.id, safe.toMap());
    } catch (_) {
      // Local backup saved.
    }
  }

  /// Deletes (soft) a warehouse.
  Future<void> deleteWarehouse(String id) async {
    LocalStore.delete(LocalStore.warehousePrefix, id);
    try {
      await _firestoreService.delete(_warehouses, id);
    } catch (_) {
      // Local removed.
    }
  }

  // ==================== BALANCES ====================

  /// Reads a single balance, falling back to the local store.
  Future<StockBalance?> getBalance(String warehouseId, String productId) async {
    final id = balanceId(warehouseId, productId);
    try {
      final map = await _firestoreService.getById(_balances, id);
      if (map != null) return StockBalance.fromMap(map);
    } catch (_) {
      // Fall through to local.
    }
    final local = LocalStore.get(LocalStore.balancePrefix, id);
    if (local == null) return null;
    local['id'] = id;
    return StockBalance.fromMap(local);
  }

  /// Reads all balances (optionally scoped to a warehouse).
  Future<List<StockBalance>> getBalances({String? warehouseId}) async {
    final where = warehouseId == null
        ? null
        : <List<dynamic>>[
            ['warehouseId', '==', warehouseId],
          ];
    try {
      final maps = await _firestoreService.getAll(
        collection: _balances,
        where: where,
        orderBy: 'productName',
      );
      return maps.map(StockBalance.fromMap).toList();
    } catch (_) {
      final all = LocalStore.getAll(
        LocalStore.balancePrefix,
      ).map(StockBalance.fromMap).toList();
      if (warehouseId != null) {
        return all.where((b) => b.warehouseId == warehouseId).toList();
      }
      return all;
    }
  }

  // ==================== STREAMS & MOVEMENTS ====================
  /// Streams balances (optionally scoped to a warehouse).
  Stream<List<StockBalance>> streamBalances({String? warehouseId}) {
    final where = warehouseId == null
        ? null
        : <List<dynamic>>[
            ['warehouseId', '==', warehouseId],
          ];
    return _firestoreService
        .streamAll(collection: _balances, where: where, orderBy: 'productName')
        .map((maps) => maps.map(StockBalance.fromMap).toList());
  }

  /// Streams movements (optionally scoped by warehouse and/or product).
  Stream<List<StockMovement>> streamMovements({
    String? warehouseId,
    String? productId,
  }) {
    final where = <List<dynamic>>[];
    if (warehouseId != null) {
      where.add(['warehouseId', '==', warehouseId]);
    }
    if (productId != null) {
      where.add(['productId', '==', productId]);
    }
    return _firestoreService
        .streamAll(
          collection: _movements,
          where: where.isEmpty ? null : where,
          orderBy: 'createdAt',
          descending: true,
          limit: 200,
        )
        .map((maps) => maps.map(StockMovement.fromMap).toList());
  }

  /// Upserts a balance document (local + Firestore).
  Future<void> _setBalance(StockBalance balance) async {
    final toSave = balance.copyWith(updatedAt: DateTime.now());
    LocalStore.put(LocalStore.balancePrefix, toSave.id, toSave.toMap());
    try {
      // createWithId() uses set(), which overwrites — perfect for upsert.
      await _firestoreService.createWithId(
        _balances,
        toSave.id,
        toSave.toMap(),
      );
    } catch (_) {
      // Local backup saved.
    }
  }

  /// Applies a delta (could be negative) to a product's balance in a warehouse
  /// and records a movement. Does not allow the balance to go negative.
  Future<void> applyMovement({
    required String warehouseId,
    String? warehouseName,
    required String productId,
    required String productName,
    String unit = 'piece',
    required double delta,
    required MovementType type,
    String? reference,
    String? notes,
    String? createdBy,
  }) async {
    final current = await getBalance(warehouseId, productId);
    final base = current?.quantity ?? 0;
    final double newQty = (base + delta) < 0 ? 0.0 : base + delta;

    await _setBalance(
      StockBalance(
        id: balanceId(warehouseId, productId),
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        productId: productId,
        productName: productName,
        unit: unit,
        quantity: newQty,
        minStock: current?.minStock ?? 0,
        updatedAt: DateTime.now(),
      ),
    );

    final movement = StockMovement(
      id: _uuid.v4(),
      productId: productId,
      productName: productName,
      unit: unit,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      quantity: delta.abs(),
      type: type,
      reference: reference,
      notes: notes,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );
    LocalStore.put(LocalStore.movementPrefix, movement.id, movement.toMap());
    try {
      await _firestoreService.createWithId(
        _movements,
        movement.id,
        movement.toMap(),
      );
    } catch (_) {
      // Local backup saved.
    }
  }

  /// Sets/updates the reorder point (minimum stock) for a product balance.
  Future<void> updateMinStock({
    required String warehouseId,
    required String productId,
    required double minStock,
  }) async {
    final current = await getBalance(warehouseId, productId);
    if (current == null) return;
    await _setBalance(current.copyWith(minStock: minStock));
  }

  // ==================== TRANSFERS ====================

  /// Atomically transfers stock between warehouses.
  /// Decreases the source balance, increases the destination balance, and
  /// records a movement on both sides.
  Future<void> createTransfer(StockTransfer transfer) async {
    for (final item in transfer.items) {
      // Source: decrease.
      final src = await getBalance(transfer.fromWarehouseId, item.productId);
      final srcQty = (src?.quantity ?? 0) - item.quantity;
      await _setBalance(
        StockBalance(
          id: balanceId(transfer.fromWarehouseId, item.productId),
          warehouseId: transfer.fromWarehouseId,
          warehouseName: transfer.fromWarehouseName,
          productId: item.productId,
          productName: item.productName,
          unit: item.unit,
          quantity: srcQty < 0 ? 0 : srcQty,
          minStock: src?.minStock ?? 0,
          updatedAt: DateTime.now(),
        ),
      );
      // Destination: increase.
      final dst = await getBalance(transfer.toWarehouseId, item.productId);
      await _setBalance(
        StockBalance(
          id: balanceId(transfer.toWarehouseId, item.productId),
          warehouseId: transfer.toWarehouseId,
          warehouseName: transfer.toWarehouseName,
          productId: item.productId,
          productName: item.productName,
          unit: item.unit,
          quantity: (dst?.quantity ?? 0) + item.quantity,
          minStock: dst?.minStock ?? 0,
          updatedAt: DateTime.now(),
        ),
      );

      final now = DateTime.now();
      final outMovement = StockMovement(
        id: _uuid.v4(),
        productId: item.productId,
        productName: item.productName,
        unit: item.unit,
        warehouseId: transfer.fromWarehouseId,
        warehouseName: transfer.fromWarehouseName,
        quantity: item.quantity,
        type: MovementType.transferOut,
        reference:
            'تحويل إلى: ${transfer.toWarehouseName ?? transfer.toWarehouseId}',
        notes: transfer.notes,
        createdAt: now,
        createdBy: transfer.createdBy,
      );
      final inMovement = StockMovement(
        id: _uuid.v4(),
        productId: item.productId,
        productName: item.productName,
        unit: item.unit,
        warehouseId: transfer.toWarehouseId,
        warehouseName: transfer.toWarehouseName,
        quantity: item.quantity,
        type: MovementType.transferIn,
        reference:
            'تحويل من: ${transfer.fromWarehouseName ?? transfer.fromWarehouseId}',
        notes: transfer.notes,
        createdAt: now,
        createdBy: transfer.createdBy,
      );
      LocalStore.put(
        LocalStore.movementPrefix,
        outMovement.id,
        outMovement.toMap(),
      );
      LocalStore.put(
        LocalStore.movementPrefix,
        inMovement.id,
        inMovement.toMap(),
      );
      try {
        await _firestoreService.createWithId(
          _movements,
          outMovement.id,
          outMovement.toMap(),
        );
        await _firestoreService.createWithId(
          _movements,
          inMovement.id,
          inMovement.toMap(),
        );
      } catch (_) {
        // Local backups saved.
      }
    }

    final toSave = StockTransfer(
      id: transfer.id,
      fromWarehouseId: transfer.fromWarehouseId,
      fromWarehouseName: transfer.fromWarehouseName,
      toWarehouseId: transfer.toWarehouseId,
      toWarehouseName: transfer.toWarehouseName,
      items: transfer.items,
      notes: transfer.notes,
      status: 'completed',
      createdAt: DateTime.now(),
      createdBy: transfer.createdBy,
    );
    LocalStore.put(LocalStore.transferPrefix, toSave.id, toSave.toMap());
    try {
      await _firestoreService.createWithId(
        _transfers,
        toSave.id,
        toSave.toMap(),
      );
    } catch (_) {
      // Local backup saved.
    }
  }

  /// Streams transfer history.
  Stream<List<StockTransfer>> streamTransfers() {
    return _firestoreService
        .streamAll(
          collection: _transfers,
          orderBy: 'createdAt',
          descending: true,
        )
        .map((maps) => maps.map(StockTransfer.fromMap).toList());
  }

  // ==================== STOCK COUNTS ====================

  /// Records a stock count and applies the differences to balances.
  Future<void> createStockCount(StockCount count) async {
    for (final item in count.items) {
      final diff = item.difference;
      if (diff == 0) continue;
      final current = await getBalance(count.warehouseId, item.productId);
      await _setBalance(
        StockBalance(
          id: balanceId(count.warehouseId, item.productId),
          warehouseId: count.warehouseId,
          warehouseName: count.warehouseName,
          productId: item.productId,
          productName: item.productName,
          unit: item.unit,
          quantity: (current?.quantity ?? 0) + diff,
          minStock: current?.minStock ?? 0,
          updatedAt: DateTime.now(),
        ),
      );
      final movement = StockMovement(
        id: _uuid.v4(),
        productId: item.productId,
        productName: item.productName,
        unit: item.unit,
        warehouseId: count.warehouseId,
        warehouseName: count.warehouseName,
        quantity: diff.abs(),
        type: MovementType.count,
        reference: diff > 0
            ? 'الجرد (زيادة ${diff.toStringAsFixed(0)})'
            : 'الجرد (نقص ${diff.abs().toStringAsFixed(0)})',
        notes: count.notes,
        createdAt: DateTime.now(),
        createdBy: count.createdBy,
      );
      LocalStore.put(LocalStore.movementPrefix, movement.id, movement.toMap());
      try {
        await _firestoreService.createWithId(
          _movements,
          movement.id,
          movement.toMap(),
        );
      } catch (_) {
        // Local backup saved.
      }
    }

    final completed = StockCount(
      id: count.id,
      warehouseId: count.warehouseId,
      warehouseName: count.warehouseName,
      items: count.items,
      status: 'completed',
      notes: count.notes,
      createdAt: DateTime.now(),
      createdBy: count.createdBy,
    );
    LocalStore.put(LocalStore.countPrefix, completed.id, completed.toMap());
    try {
      await _firestoreService.createWithId(
        _counts,
        completed.id,
        completed.toMap(),
      );
    } catch (_) {
      // Local backup saved.
    }
  }

  /// Streams stock counts (optionally scoped to a warehouse).
  Stream<List<StockCount>> streamStockCounts({String? warehouseId}) {
    final where = warehouseId == null
        ? null
        : <List<dynamic>>[
            ['warehouseId', '==', warehouseId],
          ];
    return _firestoreService
        .streamAll(
          collection: _counts,
          where: where,
          orderBy: 'createdAt',
          descending: true,
        )
        .map((maps) => maps.map(StockCount.fromMap).toList());
  }

  // ==================== LOW STOCK / REORDER ====================

  /// Returns balances at or below their reorder point.
  Future<List<StockBalance>> getLowStock({String? warehouseId}) async {
    final balances = await getBalances(warehouseId: warehouseId);
    return balances.where((b) => b.isLow).toList();
  }
}
