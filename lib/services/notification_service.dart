import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _notificationSound =
      RawResourceAndroidNotificationSound('notification');

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'picker_orders_v2',
    'Picker Orders',
    description: 'Notifications for new order assignments',
    importance: Importance.max,
    sound: _notificationSound,
  );

  static bool _firebaseReady = false;

  /// Initializes local notifications always; Firebase only if configured.
  static Future<void> initSafe() async {
    // Try to initialize Firebase — silently skip if google-services.json is missing.
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    } catch (e) {
      debugPrint('Firebase not configured — push notifications disabled. ($e)');
    }

    // Local notifications always work (for foreground display).
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: _notificationSound,
          playSound: true,
        ),
      ),
    );
  }

  /// Registers FCM token after login — silently skips if Firebase not ready.
  static Future<void> registerTokenSafe() async {
    if (!_firebaseReady) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) {
        await AuthService.updateFcmToken(token);
      }
      messaging.onTokenRefresh.listen(AuthService.updateFcmToken);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }
}
