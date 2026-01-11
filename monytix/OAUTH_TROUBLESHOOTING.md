# OAuth Troubleshooting Guide

## Current Issue

After clicking "Sign in with Google", the browser opens and shows the Supabase authorization page, but the callback doesn't redirect back to the app.

## What Should Happen

1. User clicks "Sign in with Google"
2. Browser opens with Supabase OAuth page ✅ (This is working)
3. User authorizes with Google
4. Supabase redirects to: `io.supabase.monytix://login-callback/?code=...`
5. macOS should open the app via the URL scheme
6. App receives the deep link and exchanges code for session
7. User is signed in

## Debugging Steps

### 1. Check if Deep Link is Received

When you complete OAuth in the browser, check the Flutter console/logs for:
- `"Received deep link: ..."` - This confirms the app received the callback
- `"Exchanging OAuth code for session..."` - This confirms code extraction worked
- `"OAuth sign in successful!"` - This confirms the session was created

### 2. Test URL Scheme Manually

Open Terminal and test if the URL scheme is registered:

```bash
open "io.supabase.monytix://login-callback/?code=test123"
```

This should open the app. If it doesn't, the URL scheme isn't properly registered.

### 3. Verify Supabase Redirect URL

In Supabase Dashboard → Authentication → URL Configuration:
- Ensure `io.supabase.monytix://login-callback/` is in the list
- The trailing slash is important!

### 4. Check Browser Console

After authorizing, check the browser's developer console (F12) to see:
- If there's a redirect happening
- Any errors during the redirect
- The exact URL being redirected to

### 5. Common Issues

**Issue: Browser shows authorization page but nothing happens after**
- **Cause**: Deep link not being triggered
- **Fix**: Ensure app is running when you complete OAuth. The app must be running to receive the deep link.

**Issue: "No code or tokens found in callback URI"**
- **Cause**: The redirect URL format might be different
- **Fix**: Check the actual redirect URL in browser console. It might be using a different format.

**Issue: App doesn't open when clicking the redirect link**
- **Cause**: URL scheme not properly registered
- **Fix**: Rebuild the app: `flutter clean && flutter run`

## Manual Testing

1. **Keep the app running** in the background
2. Click "Sign in with Google" in the app
3. Complete authorization in the browser
4. Watch the Flutter console for debug messages
5. The app should automatically sign you in

## Alternative: Check Browser URL After Authorization

After authorizing, look at the browser's address bar. You should see it trying to redirect to:
```
io.supabase.monytix://login-callback/?code=...
```

If you see this URL in the browser but the app doesn't open, it's a macOS URL scheme registration issue.

## Next Steps

If the deep link still doesn't work:
1. Check macOS Console app for system-level errors
2. Verify the app's bundle identifier matches the URL scheme
3. Try rebuilding the app completely: `flutter clean && flutter pub get && flutter run`

