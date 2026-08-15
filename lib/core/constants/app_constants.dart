import 'package:flutter/src/material/dropdown.dart';

/// App Constants
///
/// Centralized application constants used throughout the app.
/// Includes database name, app name, storage keys, and default values.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // App Info
  static const String appName = 'Marivio ERP';
  static const String appNameAr = 'ماريفيو ERP';
  static const String appVersion = '1.0.0';

  // Database
  static const String databaseName = 'marivio_erp.db';
  static const int databaseVersion = 1;

  // Hive Box Names
  static const String settingsBox = 'settings';
  static const String cacheBox = 'cache';
  static const String authBox = 'auth';

  // Storage Keys
  static const String themeModeKey = 'theme_mode';
  static const String localeKey = 'locale';
  static const String companyLogoKey = 'company_logo';
  static const String companyNameKey = 'company_name';
  static const String taxPercentageKey = 'tax_percentage';
  static const String currencyKey = 'currency';

  // Default Values
  static const double defaultTaxPercentage = 14.0;
  static const String defaultCurrency = 'EGP';
  static const String defaultCurrencySymbol = 'ج.م';

  // Pagination
  static const int defaultPageSize = 20;
  static const int productsPageSize = 24;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // UI
  static const double cardBorderRadius = 16.0;
  static const double buttonBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
}

/// User Roles for Role-Based Access Control (RBAC)
enum UserRole {
  owner('Owner', 'مالك'),
  admin('Admin', 'مدير'),
  salesManager('Sales Manager', 'مدير مبيعات'),
  salesRepresentative('Sales Representative', 'مندوب مبيعات'),
  warehouse('Warehouse', 'مخزن'),
  Supplier('supplier','مورد'),
  accountant('Accountant', 'محاسب');

  final String en;
  final String ar;
  const UserRole(this.en, this.ar);
}

/// Customer Types
enum CustomerType {
  normal('Normal Customer', 'عميل عادي'),
  hotel('Hotel', 'فندق'),
  restaurant('Restaurant', 'مطعم'),
  supermarket('Supermarket', 'سوبر ماركت'),
  factory('Factory', 'مصنع'),
  Supplier('supplier','مورد');

  final String en;
  final String ar;
  const CustomerType(this.en, this.ar);

  static map(DropdownMenuItem<Object> Function(String) param0) {}
}

/// Printed Order Status
enum PrintedOrderStatus {
  newOrder('New', 'جديد'),
  inProduction('In Production', 'قيد الإنتاج'),
  ready('Ready', 'جاهز'),
  delivered('Delivered', 'تم التسليم');

  final String en;
  final String ar;
  const PrintedOrderStatus(this.en, this.ar);
}

/// Invoice Status
enum InvoiceStatus {
  draft('Draft', 'مسودة'),
  unpaid('Unpaid', 'غير مدفوعة'),
  partiallyPaid('Partially Paid', 'مدفوعة جزئياً'),
  paid('Paid', 'مدفوعة'),
  cancelled('Cancelled', 'ملغاة');

  final String en;
  final String ar;
  const InvoiceStatus(this.en, this.ar);
}

/// Expense Categories
enum ExpenseCategory {
  salaries('Salaries', 'رواتب'),
  rent('Rent', 'إيجار'),
  transportation('Transportation', 'مواصلات'),
  electricity('Electricity', 'كهرباء'),
  internet('Internet', 'إنترنت'),
  maintenance('Maintenance', 'صيانة'),
  fuel('Fuel', 'وقود'),
  miscellaneous('Miscellaneous', 'متفرقات');

  final String en;
  final String ar;
  const ExpenseCategory(this.en, this.ar);
}