import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart'; // login() calls ApiService.post

class AuthService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';
  static const _keyUiConfig = 'ui_config';
  static const _keyLoginAt = 'auth_login_at';
  static const _sessionDays = 7;

  static Future<Map<String, dynamic>> login({
    String projectCode = '',
    String storeCode = '',
    required String email,
    required String password,
  }) async {
    final res = await ApiService.post('/auth/login', {
      'project_code': projectCode,
      'store_code': storeCode,
      'email': email,
      'password': password,
    });

    await _storage.write(key: _keyToken, value: res['token'] as String);
    await _storage.write(key: _keyUser, value: jsonEncode(res['user']));
    await _storage.write(key: _keyUiConfig, value: jsonEncode(res['ui_config']));
    await _storage.write(
      key: _keyLoginAt,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    // Migrate away from any old SharedPreferences data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    await prefs.remove('ui_config');

    return res;
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    await ApiService.put('/auth/fcm-token', {'fcm_token': fcmToken});
  }

  /// Re-fetch the current user + ui_config (with effective capabilities) from
  /// the backend and rewrite the cache. Used to pick up permission changes
  /// without a full re-login. Does NOT reset the 7-day login anchor.
  /// Returns the refreshed (user, uiConfig) or null if not refreshable.
  static Future<({PickerUser user, UiConfig uiConfig})?> refreshSession() async {
    final token = await getToken();
    if (token == null) return null;
    final res = await ApiService.get('/auth/me');
    final user = PickerUser.fromJson(res['user']);
    final uiConfig = UiConfig.fromJson(res['ui_config'] ?? {});
    await _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));
    await _storage.write(key: _keyUiConfig, value: jsonEncode(res['ui_config']));
    return (user: user, uiConfig: uiConfig);
  }

  /// Picker self-toggles their `is_active` flag.
  /// Round-robin will skip inactive pickers on the next assignment.
  static Future<PickerUser> setMyAvailability(bool isActive) async {
    final res = await ApiService.patch(
      '/picker/me/availability',
      {'is_active': isActive},
    );
    final updated = PickerUser.fromJson(res['data']);
    await _storage.write(key: _keyUser, value: jsonEncode(updated.toJson()));
    return updated;
  }

  /// Rider self-toggles `rider_availability` (online/offline). Round-robin
  /// rider assignment skips offline riders (riderRoundRobinService.js).
  static Future<PickerUser> setMyRiderAvailability(bool online) async {
    final res = await ApiService.patch(
      '/rider/me/availability',
      {'online': online},
    );
    final updated = PickerUser.fromJson(res['data']);
    await _storage.write(key: _keyUser, value: jsonEncode(updated.toJson()));
    return updated;
  }

  static Future<void> logout() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyUser);
    await _storage.delete(key: _keyUiConfig);
    await _storage.delete(key: _keyLoginAt);
  }

  static Future<bool> _isSessionValid() async {
    final loginAtStr = await _storage.read(key: _keyLoginAt);
    if (loginAtStr == null) return false;
    final loginAt = DateTime.fromMillisecondsSinceEpoch(int.parse(loginAtStr));
    return DateTime.now().difference(loginAt).inDays < _sessionDays;
  }

  static Future<PickerUser?> getCachedUser() async {
    if (!await _isSessionValid()) {
      await logout();
      return null;
    }
    final userJson = await _storage.read(key: _keyUser);
    if (userJson == null) return null;
    return PickerUser.fromJson(jsonDecode(userJson));
  }

  static Future<UiConfig?> getCachedUiConfig() async {
    final configJson = await _storage.read(key: _keyUiConfig);
    if (configJson == null) return null;
    return UiConfig.fromJson(jsonDecode(configJson));
  }

  static Future<String?> getToken() async {
    if (!await _isSessionValid()) {
      await logout();
      return null;
    }
    return _storage.read(key: _keyToken);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
