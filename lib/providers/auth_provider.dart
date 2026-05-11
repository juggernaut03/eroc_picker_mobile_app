import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  PickerUser? _user;
  UiConfig? _uiConfig;
  bool _loading = false;
  String? _error;

  PickerUser? get user => _user;
  UiConfig? get uiConfig => _uiConfig;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  Future<void> loadCached() async {
    _user = await AuthService.getCachedUser();
    _uiConfig = await AuthService.getCachedUiConfig();
    notifyListeners();
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

  /// Picker self-toggle of `is_active`. Throws on failure.
  Future<void> setAvailability(bool isActive) async {
    final updated = await AuthService.setMyAvailability(isActive);
    _user = updated;
    notifyListeners();
  }
}
