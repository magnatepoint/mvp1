import '../services/api_service.dart';

class BudgetService {
  final ApiService _api;

  BudgetService(this._api);

  Future<Map<String, dynamic>> getRecommendations({String? month}) async {
    final query = month != null ? '?month=$month' : '';
    return await _api.get('/v1/budget/recommendations$query');
  }

  Future<Map<String, dynamic>> commitBudget({
    required String planCode,
    String? month,
    Map<String, double>? goalAllocations,
  }) async {
    return await _api.post('/v1/budget/commit', {
      'plan_code': planCode,
      if (month != null) 'month': month,
      if (goalAllocations != null) 'goal_allocations': goalAllocations,
    });
  }

  Future<Map<String, dynamic>> getCommittedBudget({String? month}) async {
    final query = month != null ? '?month=$month' : '';
    return await _api.get('/v1/budget/commit$query');
  }

  Future<Map<String, dynamic>> getBudgetVariance({String? month}) async {
    final query = month != null ? '?month=$month' : '';
    return await _api.get('/v1/budget/variance$query');
  }
}

