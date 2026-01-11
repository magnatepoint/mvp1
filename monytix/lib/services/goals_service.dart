import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class GoalsService {
  final ApiService _api;

  GoalsService(this._api);

  Future<List<dynamic>> getGoals() async {
    try {
      final response = await _api.get('/v1/goals');
      debugPrint('getGoals response type: ${response.runtimeType}');
      debugPrint('getGoals response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      
      // _handleResponse wraps lists in {'data': [...]}
      // Backend returns a list directly, so check for 'data' key first
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            return List<dynamic>.from(data);
          }
        } else if (response.containsKey('goals')) {
          return List<dynamic>.from(response['goals'] ?? []);
        }
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error in getGoals: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<Map<String, dynamic>> getGoalProgress() async {
    try {
      final response = await _api.get('/v1/goals/progress');
      debugPrint('getGoalProgress response type: ${response.runtimeType}');
      debugPrint('getGoalProgress response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      
      // FastAPI returns Pydantic models as dicts
      // GoalsProgressResponse should have a 'goals' key
      if (response is Map<String, dynamic>) {
        // Check if 'goals' key exists and is a list
        if (response.containsKey('goals')) {
          final goalsData = response['goals'];
          if (goalsData is List) {
            return response;
          } else {
            // If 'goals' is not a list, wrap it
            return {'goals': [goalsData]};
          }
        } else {
          // If response doesn't have 'goals' key, check if it's a list wrapped in 'data'
          if (response.containsKey('data') && response['data'] is List) {
            return {'goals': response['data']};
          }
          // Otherwise wrap the whole response
          return {'goals': [response]};
        }
      }
      // If response is a list (shouldn't happen but handle it), wrap it
      if (response is List) {
        debugPrint('Warning: getGoalProgress received List directly');
        return {'goals': response};
      }
      // Fallback: wrap in goals key
      debugPrint('Warning: getGoalProgress received unexpected type: ${response.runtimeType}');
      return {'goals': []};
    } catch (e, stackTrace) {
      debugPrint('Error in getGoalProgress: $e');
      debugPrint('Stack trace: $stackTrace');
      // Return empty structure on error
      return {'goals': []};
    }
  }

  Future<List<dynamic>> getSignals() async {
    try {
      final response = await _api.get('/v1/goals/signals');
      debugPrint('getSignals response type: ${response.runtimeType}');
      debugPrint('getSignals response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      
      // _handleResponse wraps lists in {'data': [...]}
      // Backend returns a list directly, so check for 'data' key first
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            return List<dynamic>.from(data);
          }
        } else if (response.containsKey('signals')) {
          return List<dynamic>.from(response['signals'] ?? []);
        }
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error in getSignals: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<dynamic>> getSuggestions() async {
    try {
      final response = await _api.get('/v1/goals/suggestions');
      debugPrint('getSuggestions response type: ${response.runtimeType}');
      debugPrint('getSuggestions response keys: ${response is Map ? (response as Map).keys.toList() : 'not a map'}');
      
      // _handleResponse wraps lists in {'data': [...]}
      // Backend returns a list directly, so check for 'data' key first
      if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            return List<dynamic>.from(data);
          }
        } else if (response.containsKey('suggestions')) {
          return List<dynamic>.from(response['suggestions'] ?? []);
        }
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error in getSuggestions: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<Map<String, dynamic>> submitGoal(Map<String, dynamic> goalData) async {
    return await _api.post('/v1/goals/submit', goalData);
  }

  Future<List<dynamic>> getGoalCatalog() async {
    try {
      final response = await _api.get('/v1/goals/catalog');
      if (response is List) {
        final listResponse = response as List;
        return List<dynamic>.from(listResponse);
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            return List<dynamic>.from(data);
          }
        }
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error in getGoalCatalog: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<dynamic>> getRecommendedGoals() async {
    try {
      final response = await _api.get('/v1/goals/recommended');
      if (response is List) {
        final listResponse = response as List;
        return List<dynamic>.from(listResponse);
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('data')) {
          final data = response['data'];
          if (data is List) {
            return List<dynamic>.from(data);
          }
        }
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('Error in getRecommendedGoals: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLifeContext() async {
    try {
      final response = await _api.get('/v1/goals/context');
      if (response is Map<String, dynamic>) {
        return response;
      }
      return null;
    } catch (e) {
      // 404 is expected if no context exists
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        debugPrint('No life context found (expected for new users)');
        return null;
      }
      debugPrint('Error in getLifeContext: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateLifeContext(Map<String, dynamic> context) async {
    return await _api.put('/v1/goals/context', context);
  }

  Future<Map<String, dynamic>> submitGoals({
    required Map<String, dynamic>? context,
    required List<Map<String, dynamic>> selectedGoals,
  }) async {
    final payload = {
      'context': context ?? {},
      'selected_goals': selectedGoals,
    };
    return await _api.post('/v1/goals/submit', payload);
  }
}

