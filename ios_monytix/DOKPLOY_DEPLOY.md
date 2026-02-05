# iOS App: Using a Dokploy-Deployed Backend

The Monytix iOS app talks to your backend API. When the backend is deployed on **Dokploy** (or any custom host), point the app at that URL.

---

## Set the API base URL

The app reads the backend URL from **Info.plist** so you can change it per build without editing code.

### Option 1: Edit Info.plist (Xcode)

1. Open the project in Xcode.
2. Select the **ios_monytix** target → **Info** tab (or open `Info.plist`).
3. Find the key **`API_BASE_URL`**.
4. Set its value to your Dokploy backend URL, e.g.:
   - `https://api.yourdomain.com`
   - No trailing slash.

If the key is missing, add it:

- **Key:** `API_BASE_URL`  
- **Type:** String  
- **Value:** `https://api.yourdomain.com`

### Option 2: xcconfig (per scheme / environment)

1. Create a `.xcconfig` file (e.g. `Config-Dokploy.xcconfig`) with:
   ```
   API_BASE_URL = https://api.yourdomain.com
   ```
2. In Xcode, assign that xcconfig to the target’s build configuration.
3. Ensure the target’s **Info** plist is set to substitute variables, and add:
   - Key: `API_BASE_URL`  
   - Value: `$(API_BASE_URL)`  
   with a default in the project’s main plist or another xcconfig if needed.

### Default

If `API_BASE_URL` is missing or empty, the app uses:

- **`https://api.monytix.ai`**

---

## Code reference

- **Config:** `ios_monytix/Config.swift` — `Config.apiBaseUrl` reads `API_BASE_URL` from `Bundle.main` and falls back to the default.
- **Services:** All API calls (SpendSense, Budget, Goals, etc.) use `Config.apiBaseUrl` via their service initialisation.

---

## After changing the URL

1. Clean build (Product → Clean Build Folder).
2. Run the app again; it will use the new backend.

---

## CORS and auth

- The iOS app sends requests with `Authorization: Bearer <token>` (Supabase JWT).
- Your Dokploy backend must allow your Supabase project’s JWT and CORS for the app (mobile apps typically don’t trigger browser CORS; ensure `FRONTEND_ORIGIN` or equivalent is set if you also have a web app).
- Use **HTTPS** in production; for local/dev, the app can use HTTP if allowed by App Transport Security (e.g. exception domains in Info.plist).
