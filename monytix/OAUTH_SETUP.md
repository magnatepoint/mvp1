# OAuth Setup for Google Sign-In

## Current Status

The OAuth flow is configured, but you need to complete the setup in Supabase.

## What's Happening

When you click "Sign in with Google":
1. ✅ The app opens your browser (expected behavior)
2. ✅ You see the Supabase authorization page
3. ⚠️ After authorization, it needs to redirect back to the app

## Required Configuration

### 1. Configure Redirect URL in Supabase

1. Go to your Supabase project dashboard: https://supabase.com/dashboard
2. Navigate to **Authentication** → **URL Configuration**
3. Add the following redirect URL to **Redirect URLs**:
   ```
   io.supabase.monytix://login-callback/
   ```

### 2. Verify macOS URL Scheme

The URL scheme is already configured in `macos/Runner/Info.plist`:
- Scheme: `io.supabase.monytix`
- Path: `login-callback`

### 3. How It Works

1. User clicks "Sign in with Google"
2. Browser opens with Supabase OAuth page
3. User authorizes with Google
4. Supabase redirects to: `io.supabase.monytix://login-callback/?code=...`
5. macOS opens the app via the URL scheme
6. App handles the deep link and exchanges code for session
7. User is automatically signed in

## Testing

After configuring the redirect URL in Supabase:
1. Click "Sign in with Google" in the app
2. Complete authorization in the browser
3. The app should automatically receive the callback and sign you in

## Troubleshooting

If the callback doesn't work:
- Verify the redirect URL is exactly: `io.supabase.monytix://login-callback/`
- Check macOS Console for deep link errors
- Ensure the app is running when you complete OAuth in the browser

