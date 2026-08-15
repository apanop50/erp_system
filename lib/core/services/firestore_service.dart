/// Firestore Service
///
/// Generic Firestore CRUD operations service.
/// Provides reusable methods for all Firestore collections.
/// Supports real-time streams, pagination, batch writes, and transactions.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_service.dart';
import 'local_store.dart';

/// Generic Firestore service for CRUD operations.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseService.firestore;

  /// Creates a document in the specified [collection] with auto-generated ID.
  Future<String> create(String collection, Map<String, dynamic> data) async {
    final docRef = await _db.collection(collection).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    }).timeout(const Duration(seconds: 8));
    return docRef.id;
  }

  /// Creates a document with a specific [id] in the specified [collection].
  Future<void> createWithId(String collection, String id, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(id).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
    }).timeout(const Duration(seconds: 8));
  }

  /// Gets a single document by [id] from the specified [collection].
  /// Falls back to [LocalStore] when Firestore is unreachable.
  Future<Map<String, dynamic>?> getById(String collection, String id) async {
    try {
      final doc = await _db.collection(collection).doc(id).get()
          .timeout(const Duration(seconds: 8));
      if (!doc.exists) return null;
      return {'id': doc.id, ...?doc.data()};
    } catch (e) {
      // Fall back to local store.
      final local = LocalStore.get(LocalStore.prefixForCollection(collection), id);
      if (local == null) return null;
      local['id'] = id;
      return local;
    }
  }

  /// Gets a stream of a single document by [id].
  /// On error, emits the cached local value (once) then stays quiet.
  Stream<Map<String, dynamic>?> streamById(String collection, String id) {
    late StreamSubscription<DocumentSnapshot> sub;
    final controller = StreamController<Map<String, dynamic>?>.broadcast();
    final prefix = LocalStore.prefixForCollection(collection);
    // Emit local cache immediately if available.
    final cached = LocalStore.get(prefix, id);
    if (cached != null) {
      cached['id'] = id;
      controller.add(cached);
    }
    sub = _db.collection(collection).doc(id).snapshots().listen(
      (doc) {
        if (!doc.exists) {
          controller.add(null);
        } else {
          controller.add({'id': doc.id, ...?doc.data()});
        }
      },
      onError: (e) {
        // Silently ignore stream errors (offline, permission denied, etc.).
        // The local cache served initial data already.
      },
      cancelOnError: false,
    );
    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  /// Gets all documents from a collection with optional filters.
  /// Falls back to local store when Firestore is unreachable.
  Future<List<Map<String, dynamic>>> getAll({
    required String collection,
    List<List<dynamic>>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      Query query = _db.collection(collection).where('isDeleted', isEqualTo: false);

      if (where != null) {
        for (final condition in where) {
          query = query.where(condition[0] as String, isEqualTo: condition[2]);
        }
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query
          .get()
          .timeout(const Duration(seconds: 8));
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      // Fall back to local store (also on timeout/offline).
      final prefix = LocalStore.prefixForCollection(collection);
      return LocalStore.getAll(prefix);
    }
  }

  /// Gets a real-time stream of all documents in a collection.
  /// On error, emits the cached local data (once) then stays quiet.
  Stream<List<Map<String, dynamic>>> streamAll({
    required String collection,
    List<List<dynamic>>? where,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<QuerySnapshot>? activeSub;
    final prefix = LocalStore.prefixForCollection(collection);

    // Emit local cache immediately.
    final cached = LocalStore.getAll(prefix);
    if (cached.isNotEmpty) {
      controller.add(cached);
    }

    try {
      Query query = _db.collection(collection).where('isDeleted', isEqualTo: false);

      if (where != null) {
        for (final condition in where) {
          query = query.where(condition[0] as String, isEqualTo: condition[2]);
        }
      }

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      activeSub = query.snapshots().listen(
        (snapshot) {
          final list = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
          controller.add(list);
        },
        onError: (e) {
          // Stream error: local cache already emitted.
        },
        cancelOnError: false,
      );
    } catch (e) {
      // Query construction failed (e.g. offline). Local cache already emitted.
    }

    controller.onCancel = () => activeSub?.cancel();
    return controller.stream;
  }

  /// Updates a document by [id] in the specified [collection].
  Future<void> update(String collection, String id, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  /// Soft-deletes a document by setting isDeleted to true.
  Future<void> delete(String collection, String id) async {
    await _db.collection(collection).doc(id).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 8));
  }

  /// Hard-deletes a document (removes it permanently).
  Future<void> hardDelete(String collection, String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  /// Performs a batch write for multiple operations.
  Future<void> batchWrite(List<BatchOperation> operations) async {
    final batch = _db.batch();
    for (final op in operations) {
      final docRef = _db.collection(op.collection).doc(op.id);
      switch (op.type) {
        case BatchOperationType.create:
          batch.set(docRef, {
            ...op.data,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isDeleted': false,
          });
          break;
        case BatchOperationType.update:
          batch.update(docRef, {
            ...op.data,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          break;
        case BatchOperationType.delete:
          batch.update(docRef, {
            'isDeleted': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          break;
      }
    }
    await batch.commit();
  }

  /// Runs a transaction for atomic operations.
  Future<T> runTransaction<T>(Future<T> Function(Transaction) action) async {
    return _db.runTransaction(action);
  }

  /// Counts documents in a collection.
  /// Falls back to the local store count when Firestore is unreachable.
  Future<int> count(String collection) async {
    try {
      final snapshot = await _db.collection(collection)
          .where('isDeleted', isEqualTo: false)
          .count()
          .get()
          .timeout(const Duration(seconds: 8));
      return snapshot.count ?? 0;
    } catch (e) {
      final prefix = LocalStore.prefixForCollection(collection);
      final local = LocalStore.getAll(prefix);
      return local.where((m) => m['isDeleted'] != true).length;
    }
  }

  /// Searches documents by a text field.
  /// Falls back to a local substring search when Firestore is unreachable.
  Future<List<Map<String, dynamic>>> search({
    required String collection,
    required String searchField,
    required String searchValue,
    int? limit,
  }) async {
    try {
      Query query = _db.collection(collection)
          .where('isDeleted', isEqualTo: false)
          .where(searchField, isGreaterThanOrEqualTo: searchValue)
          .where(searchField, isLessThanOrEqualTo: '$searchValue\uf8ff');

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query
          .get()
          .timeout(const Duration(seconds: 8));
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      // Fall back to a local contains-search.
      final prefix = LocalStore.prefixForCollection(collection);
      final lower = searchValue.toLowerCase();
      return LocalStore.getAll(prefix)
          .where((m) {
            final field = (m[searchField] as String? ?? '').toLowerCase();
            return field.contains(lower);
          })
          .take(limit ?? 20)
          .toList();
    }
  }
}

/// Batch operation model.
class BatchOperation {
  final BatchOperationType type;
  final String collection;
  final String id;
  final Map<String, dynamic> data;

  const BatchOperation({
    required this.type,
    required this.collection,
    required this.id,
    this.data = const {},
  });
}

/// Batch operation types.
enum BatchOperationType { create, update, delete }