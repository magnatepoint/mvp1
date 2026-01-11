import '../services/api_service.dart';

class MoneyMomentsService {
  final ApiService _api;

  MoneyMomentsService(this._api);

  Future<Map<String, dynamic>> getMoments({String? month}) async {
    final query = month != null ? '?month=$month' : '';
    return await _api.get('/v1/moneymoments/moments$query');
  }

  Future<Map<String, dynamic>> computeMoments({String? targetMonth}) async {
    final query = targetMonth != null ? '?target_month=$targetMonth' : '';
    return await _api.post('/v1/moneymoments/moments/compute$query', {});
  }

  Future<Map<String, dynamic>> getNudges({int limit = 20}) async {
    return await _api.get('/v1/moneymoments/nudges?limit=$limit');
  }

  Future<Map<String, dynamic>> evaluateNudges({String? asOfDate}) async {
    final query = asOfDate != null ? '?as_of_date=$asOfDate' : '';
    return await _api.post('/v1/moneymoments/nudges/evaluate$query', {});
  }

  Future<Map<String, dynamic>> processNudges({int limit = 10}) async {
    return await _api.post('/v1/moneymoments/nudges/process?limit=$limit', {});
  }

  Future<Map<String, dynamic>> computeSignal({String? asOfDate}) async {
    final query = asOfDate != null ? '?as_of_date=$asOfDate' : '';
    return await _api.post('/v1/moneymoments/signals/compute$query', {});
  }
}

