/// Data Pages
///
/// Display screens for the `warehouses`, `tenants`, and `cancel_requests`
/// Firestore collections. Read directly from Firestore via the inventory
/// providers so the real Firebase data appears in the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/inventory/inventory_repository.dart';
import '../../core/widgets/common_widgets.dart';

/// Generic helper to render a simple list from a stream.
class _StreamListPage<T> extends ConsumerWidget {
  final String title;
  final IconData icon;
  final StreamProvider<List<T>> stream;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyText;

  const _StreamListPage({
    required this.title,
    required this.icon,
    required this.stream,
    required this.itemBuilder,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stream);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ في تحميل البيانات: $e')),
        data: (items) => items.isEmpty
            ? EmptyState(icon: icon, title: title, subtitle: emptyText)
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
                      title: itemBuilder(context, items[index]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Warehouses page - displays data from the `warehouses` collection.
class WarehousesPage extends StatelessWidget {
  const WarehousesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StreamListPage<Warehouse>(
      title: 'المخازن',
      icon: Icons.warehouse_outlined,
      stream: warehousesStreamProvider,
      emptyText: 'لا توجد مخازن',
      itemBuilder: (context, w) => Row(
        children: [
          Expanded(child: Text(w.name, style: const TextStyle(fontSize: 16))),
          if (w.createdAt != null)
            Text(
              DateFormat('yyyy-MM-dd').format(w.createdAt!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// Tenants page - displays data from the `tenants` collection.
class TenantsPage extends StatelessWidget {
  const TenantsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StreamListPage<Tenant>(
      title: 'الشركاء',
      icon: Icons.group_outlined,
      stream: tenantsStreamProvider,
      emptyText: 'لا يوجد شركاء',
      itemBuilder: (context, t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.name, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text(
            'رأس المال: ${NumberFormat("#,##0").format(t.capital)}  |  النسبة: ${t.percentage}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Cancel Requests page - displays data from the `cancel_requests` collection.
class CancelRequestsPage extends StatelessWidget {
  const CancelRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StreamListPage<CancelRequest>(
      title: 'طلبات الإلغاء',
      icon: Icons.cancel_outlined,
      stream: cancelRequestsStreamProvider,
      emptyText: 'لا توجد طلبات إلغاء',
      itemBuilder: (context, r) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.customerName ?? r.customerId ?? 'عميل',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            'الحالة: ${r.status ?? '—'}'
            '${r.createdAt != null ? '  |  ${DateFormat("yyyy-MM-dd").format(r.createdAt!)}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (r.reason != null && r.reason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                r.reason!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}