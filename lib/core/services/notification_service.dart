import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Inisialisasi notification service
  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Handler ketika notifikasi di-tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle navigation berdasarkan payload
    final payload = response.payload;
    if (payload != null) {
      debugPrint('Notification tapped with payload: $payload');
    }
  }

  /// Channel ID untuk berbagai jenis notifikasi
  static const String _suratChannelId = 'surat_channel';
  static const String _iuranChannelId = 'iuran_channel';
  static const String _dokumenChannelId = 'dokumen_channel';
  static const String _chatChannelId = 'chat_channel';
  static const String _pengumumanChannelId = 'pengumuman_channel';

  /// Tampilkan notifikasi surat
  Future<void> showSuratNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _suratChannelId,
      channelName: 'Surat Pengantar',
      channelDescription: 'Notifikasi status surat pengantar',
      payload: payload,
    );
  }

  /// Tampilkan notifikasi iuran
  Future<void> showIuranNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _iuranChannelId,
      channelName: 'Iuran Warga',
      channelDescription: 'Pengingat pembayaran iuran',
      payload: payload,
    );
  }

  /// Tampilkan notifikasi dokumen
  Future<void> showDokumenNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _dokumenChannelId,
      channelName: 'Verifikasi Dokumen',
      channelDescription: 'Notifikasi status verifikasi dokumen',
      payload: payload,
    );
  }

  /// Tampilkan notifikasi chat
  Future<void> showChatNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _chatChannelId,
      channelName: 'Pesan Chat',
      channelDescription: 'Notifikasi pesan chat baru',
      payload: payload,
    );
  }

  /// Tampilkan notifikasi pengumuman
  Future<void> showPengumumanNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: _pengumumanChannelId,
      channelName: 'Pengumuman',
      channelDescription: 'Notifikasi pengumuman dari admin',
      payload: payload,
    );
  }

  /// Internal method untuk tampilkan notifikasi
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Hapus semua notifikasi
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  /// Hapus notifikasi berdasarkan ID
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _notifications.cancel(id: id);
  }
}
