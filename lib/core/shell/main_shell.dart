/// Main Shell
///
/// Responsive navigation shell for the ERP application.
/// Uses NavigationRail on desktop/tablet and BottomNavigationBar on mobile.
/// Provides navigation to all main modules of the ERP system.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Navigation item model for the shell.
class NavItem {
  final String routePath;
  final String routeName;
  final IconData icon;
  final IconData selectedIcon;
  final String labelAr;
  final String labelEn;

  const NavItem({
    required this.routePath,
    required this.routeName,
    required this.icon,
    required this.selectedIcon,
    required this.labelAr,
    required this.labelEn,
  });
}

/// All navigation items for the ERP system.
const List<NavItem> _navItems = [
  NavItem(
    routePath: '/dashboard',
    routeName: 'dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    labelAr: 'الرئيسية',
    labelEn: 'Dashboard',
  ),
  NavItem(
    routePath: '/products',
    routeName: 'products',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
    labelAr: 'المنتجات',
    labelEn: 'Products',
  ),
  NavItem(
    routePath: '/customers',
    routeName: 'customers',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    labelAr: 'العملاء',
    labelEn: 'Customers',
  ),
  NavItem(
    routePath: '/sales',
    routeName: 'sales',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
    labelAr: 'المبيعات',
    labelEn: 'Sales',
  ),
  NavItem(
    routePath: '/purchases',
    routeName: 'purchases',
    icon: Icons.shopping_cart_outlined,
    selectedIcon: Icons.shopping_cart,
    labelAr: 'المشتريات',
    labelEn: 'Purchases',
  ),
  NavItem(
    routePath: '/expenses',
    routeName: 'expenses',
    icon: Icons.money_off_outlined,
    selectedIcon: Icons.money_off,
    labelAr: 'المصروفات',
    labelEn: 'Expenses',
  ),
    NavItem(
    routePath: '/reports',
    routeName: 'reports',
    icon: Icons.assessment_outlined,
    selectedIcon: Icons.assessment,
    labelAr: 'التقارير',
    labelEn: 'Reports',
  ),
  NavItem(
    routePath: '/finance',
    routeName: 'finance',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    labelAr: 'الحسابات',
    labelEn: 'Finance',
  ),
  NavItem(
    routePath: '/settings',
    routeName: 'settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    labelAr: 'الإعدادات',
    labelEn: 'Settings',
  ),
  NavItem(
    routePath: '/warehouses',
    routeName: 'warehouses',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse,
    labelAr: 'المخازن',
    labelEn: 'Warehouses',
  ),
  NavItem(
    routePath: '/tenants',
    routeName: 'tenants',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    labelAr: 'الشركاء',
    labelEn: 'Tenants / Partners',
  ),
  NavItem(
    routePath: '/cancel-requests',
    routeName: 'cancelRequests',
    icon: Icons.cancel_outlined,
    selectedIcon: Icons.cancel,
    labelAr: 'طلبات الإلغاء',
    labelEn: 'Cancel Requests',
  ),
];

/// Responsive main shell widget.
///
/// Displays:
/// - NavigationRail on desktop (width >= 900)
/// - BottomNavigationBar on mobile (width < 600)
/// - Extended NavigationRail on tablet (600 <= width < 900)
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    // Determine current route index
    final location = GoRouterState.of(context).uri.toString();
    int selectedIndex = _getSelectedIndex(location);

    if (isDesktop || isTablet) {
      return Scaffold(
        body: Row(
          children: [
            // Navigation Rail
            _buildNavigationRail(
              context,
              selectedIndex,
              isExtended: isDesktop,
            ),
            // Vertical divider
            const VerticalDivider(width: 1, thickness: 1),
            // Main content
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile layout with bottom navigation
    return Scaffold(
      body: child,
      bottomNavigationBar: _buildBottomNav(context, selectedIndex),
    );
  }

  /// Gets the selected navigation index based on the current route.
  int _getSelectedIndex(String location) {
    for (int i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].routePath)) {
        return i;
      }
    }
    return 0;
  }

  /// Builds the NavigationRail for desktop/tablet.
  Widget _buildNavigationRail(
    BuildContext context,
    int selectedIndex, {
    required bool isExtended,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).brightness == Brightness.light
                ? AppColors.primary
                : AppColors.darkNavy,
            Theme.of(context).brightness == Brightness.light
                ? AppColors.primaryDark
                : AppColors.navyLight,
          ],
        ),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(_navItems[index].routePath);
        },
        extended: isExtended,
        backgroundColor: Colors.transparent,
        selectedIconTheme: const IconThemeData(color: AppColors.gold),
        unselectedIconTheme: IconThemeData(
          color: Colors.white.withAlpha(179),
        ),
        leading: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              if (isExtended) ...[
                const SizedBox(height: 8),
                Text(
                  'Marivio ERP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        destinations: _navItems.map((item) {
          return NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.labelAr),
          );
        }).toList(),
      ),
    );
  }

  /// Builds the BottomNavigationBar for mobile.
  Widget _buildBottomNav(BuildContext context, int selectedIndex) {
    // Only show first 5 items on mobile bottom nav
    final mobileItems = _navItems.take(5).toList();

    return BottomNavigationBar(
      currentIndex: selectedIndex < 5 ? selectedIndex : 0,
      onTap: (index) {
        context.go(mobileItems[index].routePath);
      },
      items: mobileItems.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item.icon),
          activeIcon: Icon(item.selectedIcon),
          label: item.labelAr,
        );
      }).toList(),
    );
  }
}