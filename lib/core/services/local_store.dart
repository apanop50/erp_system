/// Local Store
///
/// Lightweight local persistence layer built on top of Hive.
///
/// The ERP app writes to Firebase Firestore as its primary store. To make
/// saving reliable even when the network is unavailable or Firestore security
/// rules reject a write, we also persist a JSON copy of every record locally
/// in a dedicated Hive box (`erp_local`). Reads fall back to this local store
/// when Firestore is unreachable.
///
/// The `erp_local` box is never cleared by [CacheService.clearLocalData]
/// (which only clears the `cache` box), so user data survives app restarts.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

/// Local JSON persistence for each ERP entity.
class LocalStore {
  LocalStore._();

  static const String _boxName = 'erp_local';
  static const String productPrefix = 'product';
  static const String supplierPrefix = 'supplier';
  static const String partnerPrefix = 'partner';
  static const String customerPrefix = 'customer';
  static const String invoicePrefix = 'invoice';
  static const String purchasePrefix = 'purchase';
  static const String expensePrefix = 'expense';
  static const String financePrefix = 'finance';
  static const String partnerTxnPrefix = 'partner_txn';
  static const String warehousePrefix = 'warehouse';
  static const String balancePrefix = 'balance';
  static const String movementPrefix = 'movement';
  static const String transferPrefix = 'transfer';
  static const String countPrefix = 'count';

  static Box<String>? _box;

  /// Opens the local store box. Called once during app startup.
  static Future<void> init() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<String>(_boxName);
    } else {
      _box = await Hive.openBox<String>(_boxName);
    }
  }

  static Box<String> get _b {
    final box = _box;
    if (box == null) {
      throw StateError('LocalStore.init() must be called before use.');
    }
    return box;
  }

  static String _key(String prefix, String id) => '$prefix:$id';

  /// Maps a Firestore collection name to its [LocalStore] prefix.
  /// This keeps read fall-back and writes on the same box.
  static String prefixForCollection(String collection) {
    switch (collection) {
      case 'products':
        return productPrefix;
      case 'suppliers':
        return supplierPrefix;
      case 'tenants':
        return partnerPrefix;
      case 'partners':
        return partnerPrefix;
      case 'partner_transactions':
        return partnerTxnPrefix;
      case 'ledger':
        return financePrefix;
      case 'invoices':
        return invoicePrefix;
      case 'purchase_invoices':
        return purchasePrefix;
      case 'warehouses':
        return warehousePrefix;
      case 'stock_balances':
        return balancePrefix;
      case 'stock_movements':
        return movementPrefix;
      case 'stock_transfers':
        return transferPrefix;
      case 'stock_counts':
        return countPrefix;
      default:
        return customerPrefix;
    }
  }

  /// Persists a record locally as a JSON string.
  static void put(String prefix, String id, Map<String, dynamic> data) {
    _b.put(_key(prefix, id), jsonEncode(jsonSafe(data)));
  }

  /// Reads a single locally-persisted record.
  static Map<String, dynamic>? get(String prefix, String id) {
    final raw = _b.get(_key(prefix, id));
    if (raw == null) return null;
    return fromLocal(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Reads all locally-persisted records for a prefix.
  static List<Map<String, dynamic>> getAll(String prefix) {
    final result = <Map<String, dynamic>>[];
    for (final entry in _b.toMap().entries) {
      if (entry.key.startsWith('$prefix:')) {
        result.add(fromLocal(jsonDecode(entry.value) as Map<String, dynamic>));
      }
    }
    return result;
  }

  /// Removes a locally-persisted record.
  static void delete(String prefix, String id) {
    _b.delete(_key(prefix, id));
  }

  /// Converts a Firestore-safe map into a JSON-safe map (timestamps -> strings).
  static Map<String, dynamic> jsonSafe(Map<String, dynamic> map) {
    return map.map((k, v) => MapEntry(k, _jsonify(v)));
  }

  static dynamic _jsonify(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      return value.map((k, x) => MapEntry(k.toString(), _jsonify(x)));
    }
    if (value is List) return value.map(_jsonify).toList();
    if (value is num || value is bool || value is String) return value;
    return value.toString();
  }

  /// Restores a JSON-decoded map into a Firestore-compatible map
  /// (ISO date strings -> [Timestamp]).
  static Map<String, dynamic> fromLocal(Map<String, dynamic> map) {
    return map.map((k, v) => MapEntry(k, _restore(v)));
  }

  static dynamic _restore(dynamic value) {
    if (value is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}').hasMatch(value)) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return Timestamp.fromDate(dt);
    }
    if (value is Map) {
      return value.map((k, x) => MapEntry(k, _restore(x)));
    }
    if (value is List) return value.map(_restore).toList();
    return value;
  }
}
