/// Notifications Service
///
/// Handles local notifications for the ERP system.
/// Notifies users about low stock, unpaid balances, invoice due dates,
/// printed order completion, monthly reports, and backup completion.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Singleton service for managing local notifications.
///
/// Features:
/// - Initialize notification channels
/// - Show immediate notifications
/// - Schedule notifications
/// - Notification types: low stock, unpaid balance, invoice due, etc.
class NotificationsService {
  static final NotificationsService instance = NotificationsService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Private constructor for singleton pattern
  NotificationsService._internal();

  /// Initializes the notification service.
  ///
  /// Sets up timezone data and notification channels.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz.initializeTimeZones();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    await _createAndroidChannel();

    _isInitialized = true;
  }

  /// Creates the Android notification channel for ERP notifications.
  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      'marivio_erp_notifications',
      'Marivio ERP Notifications',
      description: 'Notifications for Marivio ERP system',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handles notification tap events.
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to relevant screen
  }

  /// Shows an immediate notification.
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'marivio_erp_notifications',
      'Marivio ERP Notifications',
      channelDescription: 'Notifications for Marivio ERP system',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Schedules a notification for a future time.
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    int id = 0,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'marivio_erp_notifications',
      'Marivio ERP Notifications',
      channelDescription: 'Notifications for Marivio ERP system',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ==================== NOTIFICATION TYPES ====================

  /// Notifies about low stock for a product.
  Future<void> notifyLowStock(String productName, double currentStock) async {
    await showNotification(
      id: 1,
      title: 'تنبيه: مخزون منخفض',
      body: 'المنتج "$productName" مخزونه منخفض ($currentStock)',
      payload: 'low_stock:$productName',
    );
  }

  /// Notifies about a customer's unpaid balance.
  Future<void> notifyUnpaidBalance(String customerName, double balance) async {
    await showNotification(
      id: 2,
      title: 'تنبيه: رصيد غير مدفوع',
      body: 'العميل "$customerName" لديه رصيد غير مدفوع: $balance',
      payload: 'unpaid_balance:$customerName',
    );
  }

  /// Notifies about an invoice due date.
  Future<void> notifyInvoiceDue(String invoiceNumber, DateTime dueDate) async {
    await scheduleNotification(
      id: 3,
      title: 'تنبيه: فاتورة مستحقة',
      body: 'الفاتورة رقم "$invoiceNumber" مستحقة اليوم',
      scheduledDate: dueDate,
    );
  }

  /// Notifies about a printed order completion.
  Future<void> notifyPrintedOrderReady(String orderName) async {
    await showNotification(
      id: 4,
      title: 'تنبيه: طلب طباعة جاهز',
      body: 'الطلب "$orderName" جاهز للتسليم',
      payload: 'printed_order_ready:$orderName',
    );
  }

  /// Notifies about monthly report availability.
  Future<void> notifyMonthlyReport(String month) async {
    await showNotification(
      id: 5,
      title: 'تنبيه: تقرير شهري جاهز',
      body: 'تقرير شهر $month جاهز للمراجعة',
      payload: 'monthly_report:$month',
    );
  }

  /// Notifies about backup completion.
  Future<void> notifyBackupCompleted() async {
    await showNotification(
      id: 6,
      title: 'تنبيه: نسخة احتياطية',
      body: 'تم إنشاء النسخة الاحتياطية بنجاح',
      payload: 'backup_completed',
    );
  }
}