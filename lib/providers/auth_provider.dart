import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  PickerUser? _user;
  UiConfig? _uiConfig;
  bool _loading = false;
  String? _error;
  DateTime? _lastRefresh;

  PickerUser? get user => _user;
  UiConfig? get uiConfig => _uiConfig;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> loadCached() async {
    _user = await AuthService.getCachedUser();
    _uiConfig = await AuthService.getCachedUiConfig();
    notifyListeners();
    // Re-register FCM token in case it rotated since last login.
    if (_user != null) NotificationService.registerTokenSafe();
  }

  Future<bool> login({
    String projectCode = '',
    String storeCode = '',
    required String email,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await AuthService.login(
        projectCode: projectCode,
        storeCode: storeCode,
        email: email,
        password: password,
      );
      _user = PickerUser.fromJson(res['user']);
      _uiConfig = UiConfig.fromJson(res['ui_config']);
      _loading = false;
      notifyListeners();
      NotificationService.registerTokenSafe(); // fire-and-forget
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _uiConfig = null;
    notifyListeners();
  }

  /// Re-sync the user + capabilities from the backend so permission changes
  /// take effect without a re-login. Safe to call repeatedly: no-ops when
  /// logged out, and throttled to avoid spamming /auth/me on rapid resumes.
  /// Never logs the user out on a transient network error.
  Future<void> refresh({bool force = false}) async {
    if (_user == null) return;
    if (!force &&
        _lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!).inSeconds < 30) {
      return;
    }
    _lastRefresh = DateTime.now();
    try {
      final result = await AuthService.refreshSession();
      if (result != null) {
        _user = result.user;
        _uiConfig = result.uiConfig;
        notifyListeners();
      }
    } catch (_) {
      // Transient failure — keep cached session; backend 403 still enforces.
    }
  }

  /// Picker self-toggle of `is_active`. Throws on failure.
  Future<void> setAvailability(bool isActive) async {
    final updated = await AuthService.setMyAvailability(isActive);
    _user = updated;
    notifyListeners();
  }

  /// Rider self-toggle of `rider_availability`. Throws on failure.
  Future<void> setRiderAvailability(bool online) async {
    final updated = await AuthService.setMyRiderAvailability(online);
    _user = updated;
    notifyListeners();
  }
}
