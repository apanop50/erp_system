/// Storage & FCM Services
///
/// Firebase Storage service for file uploads/downloads.
/// Firebase Cloud Messaging service for push notifications.
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';

/// Firebase Storage service for file uploads and downloads.
/// Uses [Uint8List] for cross-platform compatibility (web, mobile, desktop).
class StorageService {
  final FirebaseStorage _storage = FirebaseService.storage;

  /// Uploads data to Firebase Storage and returns the download URL.
  Future<String> uploadData({
    required Uint8List data,
    required String path,
    String? contentType,
  }) async {
    final ref = _storage.ref().child(path);
    final uploadTask = contentType != null
        ? ref.putData(data, SettableMetadata(contentType: contentType))
        : ref.putData(data);

    final snapshot = await uploadTask;
    return snapshot.ref.getDownloadURL();
  }

  /// Uploads a product image.
  Future<String> uploadProductImage(String productId, Uint8List image) async {
    return uploadData(
      data: image,
      path: 'products/$productId/image.jpg',
      contentType: 'image/jpeg',
    );
  }

  /// Uploads a customer logo.
  Future<String> uploadCustomerLogo(String customerId, Uint8List logo) async {
    return uploadData(
      data: logo,
      path: 'customers/$customerId/logo.jpg',
      contentType: 'image/jpeg',
    );
  }

  /// Uploads a company logo.
  Future<String> uploadCompanyLogo(Uint8List logo) async {
    return uploadData(
      data: logo,
      path: 'settings/company_logo.jpg',
      contentType: 'image/jpeg',
    );
  }

  /// Uploads a printed design file.
  Future<String> uploadPrintedDesign(String orderId, Uint8List design) async {
    return uploadData(
      data: design,
      path: 'printed_orders/$orderId/design.jpg',
      contentType: 'image/jpeg',
    );
  }

  /// Uploads an invoice PDF.
  Future<String> uploadInvoicePDF(String invoiceId, Uint8List pdf) async {
    return uploadData(
      data: pdf,
      path: 'invoices/$invoiceId/invoice.pdf',
      contentType: 'application/pdf',
    );
  }

  /// Uploads a hotel price list PDF.
  Future<String> uploadHotelPriceList(String hotelId, Uint8List pdf) async {
    return uploadData(
      data: pdf,
      path: 'hotels/$hotelId/price_list.pdf',
      contentType: 'application/pdf',
    );
  }

  /// Deletes a file from Firebase Storage.
  Future<void> deleteFile(String path) async {
    await _storage.ref(path).delete();
  }

  /// Gets the download URL for a file.
  Future<String> getDownloadURL(String path) async {
    return _storage.ref(path).getDownloadURL();
  }
}

/// Firebase Cloud Messaging service for push notifications.
class FCMService {
  final FirebaseMessaging _messaging = FirebaseService.messaging;

  /// Initializes FCM and requests permissions.
  Future<void> initialize() async {
    // Request permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get the FCM token
    final token = await _messaging.getToken();
    if (token != null) {
      // Store the token in Firestore for the current user
      // This will be handled by the auth provider
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      // Update token in Firestore
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      // Handle foreground notification
      _handleForegroundMessage(message);
    });

    // Handle background messages - only on non-web platforms
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    }
  }

  /// Handles foreground messages.
  void _handleForegroundMessage(RemoteMessage message) {
    // This will be connected to the local notifications service
    // to show a notification when the app is in the foreground
  }

  /// Subscribes to a topic for group notifications.
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribes from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Gets the current FCM token.
  Future<String?> getToken() async {
    return _messaging.getToken();
  }
}

/// Background message handler (must be top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  // Initialize Firebase if needed
}