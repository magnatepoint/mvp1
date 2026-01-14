# API Services

This directory contains API service classes for communicating with the Monytix backend.

## Setup

1. **Base URL**: Currently set to `https://api.monytix.ai` (production). The base URL is configured in `api_service.dart` and `config/env.dart`.

2. **Authentication**: The backend uses JWT tokens. Set the token using:
   ```dart
   final apiService = ApiService();
   apiService.setAuthToken('your-jwt-token');
   ```

3. **CORS**: Ensure your backend allows requests from your Flutter app's origin.

## Services

- **ApiService**: Base HTTP client with authentication support
- **SpendSenseService**: Transaction and KPI endpoints
- **GoalsService**: Goals, progress, signals, and suggestions
- **BudgetService**: Budget recommendations and variance tracking
- **MoneyMomentsService**: Behavioral insights and nudges

## Usage Example

```dart
final apiService = ApiService();
apiService.setAuthToken('your-token');

final spendSenseService = SpendSenseService(apiService);
final kpis = await spendSenseService.getKPIs();
```

## Error Handling

All services throw `ApiException` on HTTP errors. Wrap calls in try-catch:

```dart
try {
  final data = await service.getData();
} catch (e) {
  if (e is ApiException) {
    // Handle API error
  }
}
```

