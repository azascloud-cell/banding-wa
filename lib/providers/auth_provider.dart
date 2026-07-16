import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  String? _error;

  AuthStatus get status => _status;
  String? get error => _error;
  UserModel? get user => AuthService.currentUser;
  bool get isLoggedIn => _status == AuthStatus.authenticated;

  /// Dipanggil saat app start — muat token dari storage
  Future<void> init() async {
    await AuthService.loadFromStorage();
    _status = AuthService.isLoggedIn
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> register(String username, String password) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      await AuthService.register(username: username, password: password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _error = null;
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      await AuthService.login(username: username, password: password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
