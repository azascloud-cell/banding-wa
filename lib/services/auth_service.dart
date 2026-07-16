import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/user_model.dart';

class AuthService {
  AuthService._();

  static const _tokenKey = 'auth_jwt_token';
  static const _userKey = 'auth_user_json';

  // ── In-memory cache ──────────────────────────────────────────
  static String? _token;
  static UserModel? _user;

  static String? get token => _token;
  static UserModel? get currentUser => _user;
  static bool get isLoggedIn => _token != null;

  /// Header siap pakai untuk semua HTTP request
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── Persist & load ────────────────────────────────────────────
  static Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        _user = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  static Future<void> _persist(String token, UserModel user) async {
    _token = token;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<void> clear() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  // ── API calls ─────────────────────────────────────────────────
  static Future<({String token, UserModel user})> register({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiBaseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(body['error'] ?? 'Registrasi gagal');
    }
    final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
    final token = body['token'] as String;
    await _persist(token, user);
    debugPrint('[Auth] Register berhasil: ${user.username}');
    return (token: token, user: user);
  }

  static Future<({String token, UserModel user})> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${AppConstants.apiBaseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Login gagal');
    }
    final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
    final token = body['token'] as String;
    await _persist(token, user);
    debugPrint('[Auth] Login berhasil: ${user.username}');
    return (token: token, user: user);
  }

  static Future<void> logout() async {
    await clear();
  }
}
