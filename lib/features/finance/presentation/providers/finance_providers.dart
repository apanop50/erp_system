/// Finance Providers
///
/// Riverpod providers for the finance/accounting module.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/firestore_service.dart';
import '../../../inventory/inventory_repository.dart' show Tenant;
import '../../../sales/domain/sales_repository.dart';
import '../../domain/finance_model.dart';
import '../../domain/finance_repository.dart';

/// Provider for the FinanceRepository instance.
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(FirestoreService());
});

/// Future provider for the partners (tenants) list.
final partnersListProvider = FutureProvider<List<Tenant>>((ref) async {
  return ref.watch(financeRepositoryProvider).getPartners();
});

/// Future provider for the finance summary (capital + profit).
final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) async {
  return ref.watch(financeRepositoryProvider).computeSummary();
});

/// Future provider for partner transactions.
final partnerTransactionsProvider =
    FutureProvider.family<List<PartnerTransaction>, String>((ref, partnerId) {
      return ref
          .watch(financeRepositoryProvider)
          .getPartnerTransactions(partnerId);
    });

/// Provider for the SalesRepository (used to record purchase/sale profit
/// ledger entries).
final financeSalesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(FirestoreService());
});
