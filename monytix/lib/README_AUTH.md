# Authentication Setup

This Flutter app uses Supabase for authentication, similar to the web implementations in `monyweb/` and `frontend/`.

## Setup Instructions

1. **Configure Supabase Credentials**

   Edit `lib/config/env.dart` and replace the placeholder values:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

   You can find these values in your Supabase project settings:
   - Go to your Supabase project dashboard
   - Navigate to Settings → API
   - Copy the "Project URL" and "anon public" key

2. **Install Dependencies**

   Run:
   ```bash
   flutter pub get
   ```

3. **OAuth Configuration (for Google Sign-In)**

   For Google OAuth to work:
   - Configure OAuth redirect URL in Supabase: `io.supabase.monytix://login-callback/`
   - For iOS: Add URL scheme in `ios/Runner/Info.plist`
   - For Android: Add intent filter in `android/app/src/main/AndroidManifest.xml`

## Features

- ✅ Email/Password Sign In
- ✅ Email/Password Registration
- ✅ Google OAuth Sign In
- ✅ Automatic session management
- ✅ JWT token integration with API service
- ✅ Auth state persistence

## Architecture

- **`lib/config/env.dart`**: Environment configuration
- **`lib/services/supabase_client.dart`**: Supabase client wrapper
- **`lib/services/auth_service.dart`**: Authentication service layer
- **`lib/providers/auth_provider.dart`**: Auth state management with Provider
- **`lib/screens/auth/login_screen.dart`**: Login/Registration UI
- **`lib/main.dart`**: App initialization and auth wrapper

## Usage

The app automatically shows the login screen if the user is not authenticated. Once logged in, the JWT token is automatically set in the `ApiService` for all backend API calls.

