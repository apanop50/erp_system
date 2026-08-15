/// Inventory Providers
///
/// Riverpod providers for the multi-warehouse inventory module:
/// balances, movements, transfers, stock counts and low-stock (reorder) alerts.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firestore_service.dart';
import 'stock_repository.dart';

/// Provider for the [StockRepository] instance.
final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(FirestoreService());
});

/// Sentinel key used to request balances for all warehouses.
const String kAllWarehouses = '*';

/// Streams stock balances (key '*' = all warehouses, otherwise a warehouse id).
final stockBalancesProvider = StreamProvider.family<List<StockBalance>, String>(
  (ref, warehouseId) {
    final repository = ref.watch(stockRepositoryProvider);
    return repository.streamBalances(
      warehouseId: warehouseId == kAllWarehouses ? null : warehouseId,
    );
  },
);

/// Streams stock movements (key '*' = all warehouses, otherwise a warehouse id).
final stockMovementsProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, warehouseId) {
      final repository = ref.watch(stockRepositoryProvider);
      return repository.streamMovements(
        warehouseId: warehouseId == kAllWarehouses ? null : warehouseId,
      );
    });

/// Streams stock counts (key '*' = all warehouses, otherwise a warehouse id).
final stockCountsProvider = StreamProvider.family<List<StockCount>, String>((
  ref,
  warehouseId,
) {
  final repository = ref.watch(stockRepositoryProvider);
  return repository.streamStockCounts(
    warehouseId: warehouseId == kAllWarehouses ? null : warehouseId,
  );
});

/// Streams the transfer history.
final stockTransfersProvider = StreamProvider<List<StockTransfer>>((ref) {
  return ref.watch(stockRepositoryProvider).streamTransfers();
});

/// Low stock (reorder point) balances (key '*' = all warehouses).
final lowStockProvider = FutureProvider.family<List<StockBalance>, String>((
  ref,
  warehouseId,
) {
  final repository = ref.watch(stockRepositoryProvider);
  return repository.getLowStock(
    warehouseId: warehouseId == kAllWarehouses ? null : warehouseId,
  );
});
