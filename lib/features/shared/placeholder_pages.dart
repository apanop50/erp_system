/// Placeholder Pages
///
/// Temporary placeholder pages for modules that haven't been fully implemented yet.
/// These will be replaced with full implementations as each module is built.
/// Products and Customers modules are now fully implemented.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common_widgets.dart';

/// Generic placeholder page for unimplemented modules.
class PlaceholderPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? addRoute;

  const PlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.addRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (addRoute != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.go(addRoute!),
            ),
        ],
      ),
      body: EmptyState(
        icon: icon,
        title: title,
        subtitle: description,
        actionLabel: addRoute != null ? 'إضافة جديد' : null,
        onAction: addRoute != null ? () => context.go(addRoute!) : null,
      ),
    );
  }
}

// ==================== SETTINGS MODULE ====================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SettingsLink(
            icon: Icons.warehouse_outlined,
            title: 'المخازن',
            subtitle: 'عرض المخازن المخزّنة في Firebase',
            onTap: () => context.go('/warehouses'),
          ),
          _SettingsLink(
            icon: Icons.group_outlined,
            title: 'الشركاء',
            subtitle: 'عرض بيانات الشركاء / الوكلاء',
            onTap: () => context.go('/tenants'),
          ),
          _SettingsLink(
            icon: Icons.cancel_outlined,
            title: 'طلبات الإلغاء',
            subtitle: 'عرض طلبات إلغاء الفواتير',
            onTap: () => context.go('/cancel-requests'),
          ),
        ],
      ),
    );
  }
}

/// A simple settings list tile.
class _SettingsLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}