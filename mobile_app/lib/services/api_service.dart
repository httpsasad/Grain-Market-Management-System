import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Default base URL (Use 10.0.2.2 for Android Emulator, 127.0.0.1 for Desktop/Web/Local)
  static String baseUrl = 'http://127.0.0.1:8000';

  static Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', baseUrl);
  }

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('api_base_url') ?? baseUrl;
    return baseUrl;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Auth: Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      await saveToken(data['access_token']);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Login failed'};
    }
  }

  // Auth: Signup
  static Future<Map<String, dynamic>> signup({
    required String username,
    required String shopName,
    required String ownerName,
    required String mobile,
    required String city,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/v1/auth/signup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'shop_name': shopName,
        'owner_name': ownerName,
        'mobile': mobile,
        'city': city,
        'password': password,
      }),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      await saveToken(data['access_token']);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Registration failed'};
    }
  }

  // Dashboard Stats
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final url = Uri.parse('$baseUrl/api/v1/dashboard/stats');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load dashboard stats');
    }
  }

  // Parties
  static Future<List<dynamic>> getParties({String partyType = 'All'}) async {
    final url = Uri.parse('$baseUrl/api/v1/parties?party_type=$partyType');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final res = jsonDecode(utf8.decode(response.bodyBytes));
      return res['data'] ?? [];
    } else {
      throw Exception('Failed to load parties');
    }
  }

  static Future<Map<String, dynamic>> createParty(Map<String, dynamic> partyData) async {
    final url = Uri.parse('$baseUrl/api/v1/parties');
    final headers = await _getHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(partyData),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Failed to add party'};
    }
  }

  static Future<Map<String, dynamic>> updateParty(int partyId, Map<String, dynamic> partyData) async {
    final url = Uri.parse('$baseUrl/api/v1/parties/$partyId');
    final headers = await _getHeaders();
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(partyData),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Failed to update party'};
    }
  }

  static Future<bool> deleteParty(int partyId) async {
    final url = Uri.parse('$baseUrl/api/v1/parties/$partyId');
    final headers = await _getHeaders();
    final response = await http.delete(url, headers: headers);
    return response.statusCode == 200;
  }

  // Receivings (Fasal Aamad)
  static Future<List<dynamic>> getReceivings() async {
    final url = Uri.parse('$baseUrl/api/v1/receivings');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final res = jsonDecode(utf8.decode(response.bodyBytes));
      return res['data'] ?? [];
    } else {
      throw Exception('Failed to load receivings');
    }
  }

  static Future<Map<String, dynamic>> createReceiving(Map<String, dynamic> receivingData) async {
    final url = Uri.parse('$baseUrl/api/v1/receivings');
    final headers = await _getHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(receivingData),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Failed to add receiving'};
    }
  }

  // Sales & Settlements
  static Future<Map<String, dynamic>> processSale(Map<String, dynamic> saleData) async {
    final url = Uri.parse('$baseUrl/api/v1/sales/process');
    final headers = await _getHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(saleData),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Sale processing failed'};
    }
  }

  // Ledger
  static Future<Map<String, dynamic>> getLedger(int partyId) async {
    final url = Uri.parse('$baseUrl/api/v1/ledger/$partyId');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Failed to load ledger');
    }
  }

  static Future<Map<String, dynamic>> addLedgerEntry(Map<String, dynamic> entryData) async {
    final url = Uri.parse('$baseUrl/api/v1/ledger/entry');
    final headers = await _getHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(entryData),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Failed to add ledger entry'};
    }
  }

  // Payments
  static Future<List<dynamic>> getPayments({int? partyId, String paymentType = 'All'}) async {
    String query = 'payment_type=$paymentType';
    if (partyId != null) query += '&party_id=$partyId';
    final url = Uri.parse('$baseUrl/api/v1/payments?$query');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final res = jsonDecode(utf8.decode(response.bodyBytes));
      return res['data'] ?? [];
    } else {
      throw Exception('Failed to load payments');
    }
  }

  static Future<Map<String, dynamic>> createPayment(Map<String, dynamic> paymentData) async {
    final url = Uri.parse('$baseUrl/api/v1/payments');
    final headers = await _getHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(paymentData),
    );

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 200) {
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': data['detail'] ?? 'Failed to record payment'};
    }
  }

  // ML Price Prediction
  static Future<Map<String, dynamic>> getPricePrediction(int cropId, {int daysAhead = 7}) async {
    final url = Uri.parse('$baseUrl/api/ml/predict-price?crop_id=$cropId&days_ahead=$daysAhead');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    return {'predicted_rate_kg': 100.0, 'predicted_rate_mann': 4000.0, 'confidence': 85.0};
  }
}
