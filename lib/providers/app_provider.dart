import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AppProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _userToken;
  String? _userName;
  String? _error;
  List<dynamic> _cbeAccounts = [];

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _userToken != null;
  String? get userName => _userName;
  String? get error => _error;
  List<dynamic> get cbeAccounts => _cbeAccounts;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _userToken = prefs.getString('auth_token');
    if (_userToken != null) {
      await fetchUser();
      await fetchAccounts();
    }
    notifyListeners();
  }

  Future<bool> login(String name, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/login', {
        'name': name,
        'password': password,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _userToken = data['data']['token'];
        _userName = data['data']['user']['name'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _userToken!);
        await fetchAccounts();
        return true;
      } else {
        _error = data['message'] ?? 'Login failed';
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('Login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> register(String name, String password, String hotelName) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/auth/register-manager', {
        'name': name,
        'password': password,
        'hotelName': hotelName,
      });
      if (response.statusCode == 201) {
        return await login(name, password);
      } else {
        final data = jsonDecode(response.body);
        _error = data['message'] ?? 'Registration failed';
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('Register error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> fetchUser() async {
    try {
      final response = await ApiService.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userName = data['data']['user']['name'];
      } else {
        await logout();
      }
    } catch (e) {
      debugPrint('Fetch user error: $e');
    }
    notifyListeners();
  }

  Future<void> fetchAccounts() async {
    try {
      final response = await ApiService.get('/accounts');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accounts = data['data']['accounts'] as List;
        _cbeAccounts = accounts.where((a) => (a['provider']?.toString().toLowerCase() ?? '') == 'cbe').toList();
      }
    } catch (e) {
      debugPrint('Fetch accounts error: $e');
    }
    notifyListeners();
  }

  Future<bool> addCbeAccount(String accountNumber) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/accounts', {
        'provider': 'cbe',
        'accountNumber': accountNumber,
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAccounts();
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['message'] ?? 'Failed to add account';
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('Add account error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<Map<String, dynamic>?> verifyTrx(String trxId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.post('/transactions/verify', {
        'trx_id': trxId,
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      debugPrint('Verify error: $e');
      return {'success': false, 'message': 'Connection error'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteCbeAccount(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await ApiService.delete('/accounts/$id');
      if (response.statusCode == 200) {
        _cbeAccounts.removeWhere((acc) => acc['id'] == id);
        return true;
      } else {
        final data = jsonDecode(response.body);
        _error = data['message'] ?? 'Failed to delete account';
      }
    } catch (e) {
      _error = 'Connection error: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _userToken = null;
    _userName = null;
    _cbeAccounts = [];
    notifyListeners();
  }
}
