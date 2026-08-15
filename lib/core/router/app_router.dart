/// App Router
///
/// Centralized routing configuration using GoRouter.
/// Includes auth routes, auth guards, and all ERP module routes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/customers/presentation/pages/customer_detail_page.dart';
import '../../features/customers/presentation/pages/customer_form_page.dart';
import '../../features/customers/presentation/pages/customers_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/inventory/low_stock_page.dart';
import '../../features/inventory/stock_count_page.dart';
import '../../features/inventory/stock_movement_form_page.dart';
import '../../features/inventory/stock_transfer_page.dart';
import '../../features/inventory/warehouse_detail_page.dart';
import '../../features/inventory/warehouse_form_page.dart';
import '../../features/inventory/warehouses_page.dart';
import '../../features/products/presentation/pages/product_form_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/sales/presentation/pages/expenses_page.dart';
import '../../features/sales/presentation/pages/hotels_page.dart';
import '../../features/sales/presentation/pages/invoice_form_page.dart';
import '../../features/sales/presentation/pages/purchases_page.dart';
import '../../features/sales/presentation/pages/purchase_invoice_form_page.dart';
import '../../features/sales/presentation/pages/reports_page.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/sales/presentation/pages/sales_reps_page.dart';
import '../../features/shared/data_pages.dart' hide WarehousesPage;
import '../../features/shared/placeholder_pages.dart';
import '../providers/auth_providers.dart';
import '../shell/main_shell.dart';

/// Application router configuration with auth guards.
class AppRouter {
  AppRouter._();

  static const String login = 'login';
  static const String register = 'register';
  static const String dashboard = 'dashboard';
  static const String products = 'products';
  static const String productForm = 'product-form';
  static const String customers = 'customers';
  static const String customerForm = 'customer-form';
  static const String customerDetail = 'customer-detail';
  static const String sales = 'sales';
  static const String invoiceForm = 'invoice-form';
  static const String hotels = 'hotels';
  static const String salesReps = 'sales-reps';
  static const String purchases = 'purchases';
  static const String expenses = 'expenses';
  static const String reports = 'reports';
  static const String finance = 'finance';
  static const String settings = 'settings';
  static const String warehouses = 'warehouses';
  static const String tenants = 'tenants';
  static const String cancelRequests = 'cancel-requests';

  /// Creates the GoRouter configuration with auth redirect.
  static GoRouter createRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: '/dashboard',
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final isAuthenticated = ref.read(isAuthenticatedProvider);
        final isOnLogin = state.matchedLocation == '/login';
        final isOnRegister = state.matchedLocation == '/register';

        if (!isAuthenticated && !isOnLogin && !isOnRegister) {
          return '/login';
        }
        if (isAuthenticated && (isOnLogin || isOnRegister)) {
          return '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(
          name: login,
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          name: register,
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        ShellRoute(
          builder: (context, state, child) {
            return MainShell(child: child);
          },
          routes: [
            GoRoute(
              name: dashboard,
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
            GoRoute(
              name: products,
              path: '/products',
              builder: (context, state) => const ProductsPage(),
              routes: [
                GoRoute(
                  name: productForm,
                  path: 'form',
                  builder: (context, state) {
                    final productId = state.extra as String?;
                    return ProductFormPage(productId: productId);
                  },
                ),
              ],
            ),
            GoRoute(
              name: customers,
              path: '/customers',
              builder: (context, state) => const CustomersPage(),
              routes: [
                GoRoute(
                  name: customerForm,
                  path: 'form',
                  builder: (context, state) {
                    final customerId = state.extra as String?;
                    return CustomerFormPage(customerId: customerId);
                  },
                ),
                GoRoute(
                  name: customerDetail,
                  path: 'detail/:id',
                  builder: (context, state) {
                    final customerId = state.pathParameters['id']!;
                    return CustomerDetailPage(customerId: customerId);
                  },
                ),
              ],
            ),
            GoRoute(
              name: sales,
              path: '/sales',
              builder: (context, state) => const SalesPage(),
              routes: [
                GoRoute(
                  name: invoiceForm,
                  path: 'invoice-form',
                  builder: (context, state) {
                    final invoiceId = state.extra as String?;
                    return InvoiceFormPage(invoiceId: invoiceId);
                  },
                ),
              ],
            ),
            GoRoute(
              name: purchases,
              path: '/purchases',
              builder: (context, state) => const PurchasesPage(),
              routes: [
                GoRoute(
                  name: 'purchase-form',
                  path: 'form',
                  builder: (context, state) => const PurchaseInvoiceFormPage(),
                ),
              ],
            ),
            GoRoute(
              name: expenses,
              path: '/expenses',
              builder: (context, state) => const ExpensesPage(),
            ),
            GoRoute(
              name: hotels,
              path: '/hotels',
              builder: (context, state) => const HotelsPage(),
            ),
            GoRoute(
              name: salesReps,
              path: '/sales-reps',
              builder: (context, state) => const SalesRepsPage(),
            ),
            GoRoute(
              name: reports,
              path: '/reports',
              builder: (context, state) => const ReportsPage(),
            ),
            GoRoute(
              name: finance,
              path: '/finance',
              builder: (context, state) => const FinancePage(),
            ),
            GoRoute(
              name: warehouses,
              path: '/warehouses',
              builder: (context, state) => const WarehousesPage(),
              routes: [
                GoRoute(
                  name: 'warehouse-form',
                  path: 'form',
                  builder: (context, state) {
                    final warehouseId = state.extra as String?;
                    return WarehouseFormPage(warehouseId: warehouseId);
                  },
                ),
                GoRoute(
                  name: 'warehouse-detail',
                  path: 'detail/:id',
                  builder: (context, state) {
                    return WarehouseDetailPage(
                      warehouseId: state.pathParameters['id']!,
                    );
                  },
                ),
                GoRoute(
                  name: 'stock-movement',
                  path: 'movement',
                  builder: (context, state) {
                    return StockMovementFormPage(
                      warehouseId: state.extra as String?,
                    );
                  },
                ),
                GoRoute(
                  name: 'stock-transfer',
                  path: 'transfer',
                  builder: (context, state) => const StockTransferPage(),
                ),
                GoRoute(
                  name: 'stock-count',
                  path: 'count',
                  builder: (context, state) {
                    return StockCountPage(warehouseId: state.extra as String?);
                  },
                ),
                GoRoute(
                  name: 'low-stock',
                  path: 'low-stock',
                  builder: (context, state) => const LowStockPage(),
                ),
              ],
            ),
            GoRoute(
              name: tenants,
              path: '/tenants',
              builder: (context, state) => const TenantsPage(),
            ),
            GoRoute(
              name: cancelRequests,
              path: '/cancel-requests',
              builder: (context, state) => const CancelRequestsPage(),
            ),
            GoRoute(
              name: settings,
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(child: Text('No route found for: ${state.uri}')),
      ),
    );
  }
}
