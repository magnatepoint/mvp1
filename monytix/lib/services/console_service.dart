import 'package:flutter/foundation.dart';
import 'api_service.dart';

class ConsoleService {
  final ApiService _api;

  ConsoleService(this._api);

  /// Get SpendSense KPIs for dashboard
  Future<Map<String, dynamic>?> getKPIs({String? month}) async {
    try {
      final queryParams = month != null ? '?month=$month' : '';
      final response = await _api.get('/spendsense/kpis$queryParams');
      debugPrint('KPIs response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return null;
    } catch (e) {
      // 404 is expected if user has no transaction data yet
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        debugPrint('No KPIs data available yet (expected for new users)');
        return null;
      }
      debugPrint('Error fetching KPIs: $e');
      return null;
    }
  }

  /// Get budget variance (actual vs planned)
  Future<Map<String, dynamic>?> getBudgetVariance() async {
    try {
      final response = await _api.get('/v1/budget/variance');
      debugPrint('Budget variance response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return null;
    } catch (e) {
      // 404 is expected if user has no budget data yet
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        debugPrint('No budget variance data available yet (expected for new users)');
        return null;
      }
      debugPrint('Error fetching budget variance: $e');
      return null;
    }
  }

  /// Get recent transactions
  Future<List<dynamic>> getRecentTransactions({int limit = 5}) async {
    try {
      final response = await _api.get('/spendsense/transactions?limit=$limit&offset=0');
      debugPrint('Transactions response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      if (response is Map<String, dynamic>) {
        // TransactionListResponse has 'transactions' key
        if (response.containsKey('transactions')) {
          final transactions = response['transactions'];
          if (transactions is List) {
            debugPrint('Found ${transactions.length} transactions');
            return List<dynamic>.from(transactions);
          }
        } else if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            debugPrint('Found ${data.length} transactions in data key');
            return List<dynamic>.from(data);
          }
        }
      } else if (response is List) {
        final listResponse = response as List;
        debugPrint('Found ${listResponse.length} transactions (direct list)');
        return List<dynamic>.from(listResponse);
      }
      debugPrint('No transactions found in response');
      return [];
    } catch (e) {
      // 404 is expected if user has no transactions yet
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        debugPrint('No transactions available yet (expected for new users)');
        return [];
      }
      debugPrint('Error fetching recent transactions: $e');
      return [];
    }
  }


  /// Get money moments
  Future<List<dynamic>> getMoneyMoments({String? month}) async {
    try {
      final queryParams = month != null ? '?month=$month' : '';
      final response = await _api.get('/v1/moneymoments/moments$queryParams');
      debugPrint('Money moments response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      if (response is Map<String, dynamic>) {
        // Response has 'moments' key
        if (response.containsKey('moments')) {
          final moments = response['moments'];
          if (moments is List) {
            debugPrint('Found ${moments.length} money moments');
            return List<dynamic>.from(moments);
          }
        } else if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            debugPrint('Found ${data.length} moments in data key');
            return List<dynamic>.from(data);
          }
        }
      } else if (response is List) {
        final listResponse = response as List;
        debugPrint('Found ${listResponse.length} moments (direct list)');
        return List<dynamic>.from(listResponse);
      }
      debugPrint('No money moments found in response');
      return [];
    } catch (e) {
      // 404 is expected if user has no moments yet
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        debugPrint('No money moments available yet (expected for new users)');
        return [];
      }
      debugPrint('Error fetching money moments: $e');
      return [];
    }
  }
}

