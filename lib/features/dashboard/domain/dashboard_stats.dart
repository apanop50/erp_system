/// Dashboard Statistics Model & Repository
///
/// Represents aggregated statistics for the ERP dashboard.
/// Fetches data from Firestore for real-time dashboard updates.
import '../../../core/services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../products/domain/product_model.dart';
import '../../products/domain/product_repository.dart';
import '../../customers/domain/customer_repository.dart';
import '../../sales/domain/sales_model.dart';
import '../../sales/domain/sales_repository.dart';

/// Model for dashboard statistics.
class DashboardStats {
  final double todaySales;
  final double todayPurchases;
  final double todayExpenses;
  final double netProfit;
  final int customerCount;
  final int productCount;
  final int orderCount;
  final int salesRepCount;
  final List<TopProduct> topProducts;
  final List<LowStockProduct> lowStockProducts;
  final List<MonthlyData> monthlyRevenue;
  final List<MonthlyData> monthlyProfit;
  final List<RecentInvoice> recentInvoices;

  const DashboardStats({
    this.todaySales = 0,
    this.todayPurchases = 0,
    this.todayExpenses = 0,
    this.netProfit = 0,
    this.customerCount = 0,
    this.productCount = 0,
    this.orderCount = 0,
    this.salesRepCount = 0,
    this.topProducts = const [],
    this.lowStockProducts = const [],
    this.monthlyRevenue = const [],
    this.monthlyProfit = const [],
    this.recentInvoices = const [],
  });
}

/// Top selling product model.
class TopProduct {
  final String id;
  final String name;
  final int totalQuantity;
  final double totalRevenue;

  const TopProduct({
    required this.id,
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

/// Low stock product model.
class LowStockProduct {
  final String id;
  final String name;
  final double currentStock;
  final double minimumStock;

  const LowStockProduct({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.minimumStock,
  });

  factory LowStockProduct.fromProduct(Product product) {
    return LowStockProduct(
      id: product.id,
      name: product.name,
      currentStock: product.currentStock,
      minimumStock: product.minimumStock,
    );
  }
}

/// Monthly chart data model.
class MonthlyData {
  final String month;
  final double value;

  const MonthlyData({required this.month, required this.value});
}

/// Recent invoice model.
class RecentInvoice {
  final String id;
  final String invoiceNumber;
  final String customerName;
  final double grandTotal;
  final String status;
  final DateTime invoiceDate;

  const RecentInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerName,
    required this.grandTotal,
    required this.status,
    required this.invoiceDate,
  });

  factory RecentInvoice.fromInvoice(SalesInvoice invoice) {
    return RecentInvoice(
      id: invoice.id,
      invoiceNumber: invoice.invoiceNumber,
      customerName: invoice.customerName,
      grandTotal: invoice.grandTotal,
      status: invoice.status.name,
      invoiceDate: invoice.invoiceDate,
    );
  }
}

/// Dashboard Repository - handles data retrieval from Firestore.
class DashboardRepository {
  final FirestoreService _firestoreService;
  late final ProductRepository _productRepo;
  late final CustomerRepository _customerRepo;
  late final SalesRepository _salesRepo;

  DashboardRepository(this._firestoreService) {
    _productRepo = ProductRepository(_firestoreService);
    _customerRepo = CustomerRepository(_firestoreService);
    _salesRepo = SalesRepository(_firestoreService);
  }

  /// Fetches all dashboard statistics from Firestore.
  Future<DashboardStats> getDashboardStats() async {
    final results = await Future.wait([
      _salesRepo.getTodaySales(),
      _salesRepo.getTodayPurchases(),
      _salesRepo.getTodayExpenses(),
      _customerRepo.countCustomers(),
      _productRepo.countProducts(),
      _salesRepo.countInvoices(),
      _salesRepo.countRepresentatives(),
      _salesRepo.getRecentInvoices(limit: 5),
      _productRepo.getLowStockProducts(),
      _getMonthlyRevenue(),
      _getMonthlyProfit(),
      _productRepo.getAllProducts(),
      _salesRepo.getAllInvoices(limit: 500),
    ]);

    final todaySales = results[0] as double;
    final todayPurchases = results[1] as double;
    final todayExpenses = results[2] as double;
    final customerCount = results[3] as int;
    final productCount = results[4] as int;
    final orderCount = results[5] as int;
    final salesRepCount = results[6] as int;
    final recentInvoicesData = results[7] as List<SalesInvoice>;
    final lowStockData = results[8] as List<Product>;
    final monthlyRevenueData = results[9] as List<MonthlyData>;
    final monthlyProfitData = results[10] as List<MonthlyData>;
    final allProducts = results[11] as List<Product>;
    final allInvoices = results[12] as List<SalesInvoice>;

    // Build a productId -> cost(latest purchase price) map so profit can be
    // computed as (selling price - purchase cost) * quantity.
    // Real profit per invoice is recomputed from its stored items (costPrice)
    // when available, otherwise falls back to the latest product cost.
    final costByProduct = <String, double>{
      for (final p in allProducts) p.id: p.costPrice,
    };
    final todayProfitForToday = _profitOfInvoices(
      allInvoices.where((inv) => _isToday(inv.invoiceDate)).toList(),
      costByProduct,
    );

    final topProducts = <TopProduct>[];
    final productRevenueMap = <String, TopProduct>{};
    for (final invoice in allInvoices) {
      if (invoice.status == InvoiceStatus.cancelled) continue;
      for (final item in invoice.items) {
        final productId = item.productId ?? '';
        final existing = productRevenueMap[productId];
        if (existing != null) {
          productRevenueMap[productId] = TopProduct(
            id: existing.id,
            name: existing.name,
            totalQuantity: existing.totalQuantity + item.quantity.toInt(),
            totalRevenue: existing.totalRevenue + item.total,
          );
        } else {
          productRevenueMap[productId] = TopProduct(
            id: productId,
            name: item.productName,
            totalQuantity: item.quantity.toInt(),
            totalRevenue: item.total,
          );
        }
      }
    }
    topProducts.addAll(productRevenueMap.values);
    topProducts.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    return DashboardStats(
      todaySales: todaySales,
      todayPurchases: todayPurchases,
      todayExpenses: todayExpenses,
      netProfit: todayProfitForToday - todayExpenses,
      customerCount: customerCount,
      productCount: productCount,
      orderCount: orderCount,
      salesRepCount: salesRepCount,
      topProducts: topProducts.take(5).toList(),
      lowStockProducts: lowStockData
          .map(LowStockProduct.fromProduct)
          .take(5)
          .toList(),
      monthlyRevenue: monthlyRevenueData,
      monthlyProfit: monthlyProfitData,
      recentInvoices: recentInvoicesData
          .map(RecentInvoice.fromInvoice)
          .toList(),
    );
  }

  /// Returns true if [date] falls on today.
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Computes total net profit of the given invoices (selling - purchase cost
  /// on the goods, minus discounts), skipping cancelled invoices.
  double _profitOfInvoices(
    List<SalesInvoice> invoices,
    Map<String, double> costByProduct,
  ) {
    var profit = 0.0;
    for (final invoice in invoices) {
      if (invoice.status == InvoiceStatus.cancelled) continue;
      profit += _invoiceProfit(invoice, costByProduct);
    }
    return profit;
  }

  /// Computes the net profit of a single invoice:
  /// (sum of line totals - sum of purchase costs) - invoice discount.
  double _invoiceProfit(
    SalesInvoice invoice,
    Map<String, double> costByProduct,
  ) {
    var gross = 0.0;
    for (final item in invoice.items) {
      final cost = item.costPrice > 0
          ? item.costPrice
          : (costByProduct[item.productId] ?? 0);
      gross += item.total - (cost * item.quantity);
    }
    return gross - invoice.discount;
  }

  /// Gets monthly revenue for the last 6 months.
  Future<List<MonthlyData>> _getMonthlyRevenue() async {
    final result = <MonthlyData>[];
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59);
      final invoices = await _salesRepo.getAllInvoices(limit: 500);
      double revenue = 0;
      for (final invoice in invoices) {
        if (invoice.invoiceDate.isAfter(date) &&
            invoice.invoiceDate.isBefore(monthEnd) &&
            invoice.status != InvoiceStatus.cancelled) {
          revenue += invoice.grandTotal;
        }
      }
      result.add(MonthlyData(month: _getMonthName(date.month), value: revenue));
    }
    return result;
  }

  /// Gets monthly profit for the last 6 months.
  /// Profit is computed as (selling price - purchase cost) * quantity,
  /// using each product's latest purchase cost, minus operating expenses.
  Future<List<MonthlyData>> _getMonthlyProfit() async {
    final result = <MonthlyData>[];
    final now = DateTime.now();
    final allProducts = await _productRepo.getAllProducts();
    final costByProduct = <String, double>{
      for (final p in allProducts) p.id: p.costPrice,
    };
    final invoices = await _salesRepo.getAllInvoices(limit: 500);
    final expenses = await _salesRepo.getAllExpenses(limit: 500);

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(date.year, date.month + 1, 0, 23, 59, 59);

      double grossProfit = 0;
      for (final invoice in invoices) {
        if (invoice.invoiceDate.isAfter(date) &&
            invoice.invoiceDate.isBefore(monthEnd) &&
            invoice.status != InvoiceStatus.cancelled) {
          grossProfit += _invoiceProfit(invoice, costByProduct);
        }
      }

      double expensesTotal = 0;
      for (final expense in expenses) {
        if (expense.expenseDate.isAfter(date) &&
            expense.expenseDate.isBefore(monthEnd)) {
          expensesTotal += expense.amount;
        }
      }

      result.add(
        MonthlyData(
          month: _getMonthName(date.month),
          value: grossProfit - expensesTotal,
        ),
      );
    }
    return result;
  }

  /// Returns the Arabic month name.
  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }
}
