import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class ApiService {
  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Production API base URL
  // Configured to use the production backend at https://api.monytix.ai
  static String get baseUrl {
    return 'https://api.monytix.ai';
  }
  
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
      debugPrint('API Request headers include Authorization token (length: ${_authToken!.length})');
    } else {
      debugPrint('API Request: No auth token available');
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic>? body,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic>? body,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'status': 'success'};
      }
      final decoded = jsonDecode(response.body);
      // Handle both Map and List responses
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else if (decoded is List) {
        // If API returns a list, wrap it in a generic structure
        // This shouldn't happen for most endpoints, but handle it gracefully
        return {'data': decoded};
      } else {
        // Fallback for other types
        return {'data': decoded};
      }
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body,
      );
    }
  }
  
  // Public method to handle response (needed for file upload)
  Map<String, dynamic> handleResponse(http.Response response) {
    return _handleResponse(response);
  }
  
  // Expose authToken getter for file upload
  String? get authToken => _authToken;
  
  static String getConnectionErrorMessage(dynamic error) {
    if (error is SocketException || error.toString().contains('Connection failed')) {
      return 'Cannot connect to backend server.\n\n'
          'Please ensure:\n'
          '1. Backend server is running and accessible\n'
          '2. You have an active internet connection\n'
          '3. The backend URL is correctly configured\n\n'
          'Current API URL: $baseUrl';
    }
    return error.toString();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException: $statusCode - $message';
}

