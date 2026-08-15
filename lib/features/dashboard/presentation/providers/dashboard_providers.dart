/// Dashboard Providers
///
/// Riverpod providers for the dashboard module.
/// Manages dashboard statistics state and data fetching from Firestore.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../domain/dashboard_stats.dart';

/// Provider for the FirestoreService instance.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for the DashboardRepository instance.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return DashboardRepository(firestoreService);
});

/// State notifier for dashboard statistics.
class DashboardStatsNotifier extends StateNotifier<AsyncValue<DashboardStats>> {
  final DashboardRepository _repository;

  DashboardStatsNotifier(this._repository)
      : super(const AsyncValue.loading());

  /// Loads dashboard statistics from the repository.
  Future<void> loadStats() async {
    state = const AsyncValue.loading();
    try {
      final stats = await _repository.getDashboardStats();
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refreshes the dashboard statistics.
  Future<void> refresh() async {
    await loadStats();
  }
}

/// Provider for dashboard statistics state.
final dashboardStatsProvider =
    StateNotifierProvider<DashboardStatsNotifier, AsyncValue<DashboardStats>>(
        (ref) {
  final repository = ref.watch(dashboardRepositoryProvider);
  final notifier = DashboardStatsNotifier(repository);
  // Auto-load stats when provider is first accessed
  notifier.loadStats();
  return notifier;
});