import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service notifikasi lokal Android (pop-up heads-up level tinggi saat item di-like).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'favorite_high_channel';
  static const String _channelName = 'Favorit';
  static const String _channelDesc = 'Notifikasi saat item ditambahkan ke favorit';

  /// Inisialisasi plugin dan minta izin notifikasi Android 13+.
  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(settings: settings);

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _initialized = true;
    } catch (e) {
      debugPrint('[NotificationService] init dilewati: $e');
    }
  }

  /// Tampilkan pop-up banner (heads-up notification) saat item ditambahkan ke favorit.
  static Future<void> showFavoriteNotification(String itemTitle) async {
    if (kIsWeb) return;
    if (!_initialized) await init();

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max, // Wajib max agar muncul pop-up turun dari atas
        priority: Priority.high,    // Wajib high untuk heads-up banner Android
        playSound: true,
        enableVibration: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _plugin.show(
        id: notifId,
        title: 'Ditambahkan ke Favorit',
        body: itemTitle,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[NotificationService] show dilewati: $e');
    }
  }
}

