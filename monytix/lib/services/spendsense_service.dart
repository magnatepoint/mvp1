import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class SpendSenseService {
  final ApiService _api;

  SpendSenseService(this._api);

  Future<Map<String, dynamic>> getKPIs({String? month}) async {
    final query = month != null ? '?month=$month' : '';
    return await _api.get('/spendsense/kpis$query');
  }

  Future<List<String>> getAvailableMonths() async {
    final response = await _api.get('/spendsense/kpis/available-months');
    return List<String>.from(response['data'] ?? []);
  }

  Future<Map<String, dynamic>> getInsights({
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String>[];
    if (startDate != null) queryParams.add('start_date=$startDate');
    if (endDate != null) queryParams.add('end_date=$endDate');
    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await _api.get('/spendsense/insights$query');
  }

  Future<Map<String, dynamic>> getTransactions({
    int limit = 25,
    int offset = 0,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String>['limit=$limit', 'offset=$offset'];
    if (startDate != null) queryParams.add('start_date=$startDate');
    if (endDate != null) queryParams.add('end_date=$endDate');
    return await _api.get('/spendsense/transactions?${queryParams.join('&')}');
  }

  Future<Map<String, dynamic>> uploadFile(
    File file, {
    String? password,
    Function(int sent, int total)? onProgress,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/spendsense/uploads/file');
    final request = http.MultipartRequest('POST', uri);
    
    // Add authorization header
    if (_api.authToken != null) {
      request.headers['Authorization'] = 'Bearer ${_api.authToken}';
    }
    
    // Add file
    final fileLength = await file.length();
    final multipartFile = await http.MultipartFile.fromPath(
      'file',
      file.path,
    );
    request.files.add(multipartFile);
    
    // Add password if provided
    if (password != null && password.isNotEmpty) {
      request.fields['password'] = password;
    }
    
    // Send request
    // Note: The http package doesn't easily support upload progress tracking
    // We'll simulate progress by updating during the request
    if (onProgress != null) {
      onProgress(0, fileLength);
    }
    
    final streamedResponse = await request.send();
    
    // Read the response
    final response = await http.Response.fromStream(streamedResponse);
    
    // Complete progress
    if (onProgress != null) {
      onProgress(fileLength, fileLength);
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'status': 'success'};
      }
      return _api.handleResponse(response);
    } else {
      throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
    }
  }
}

