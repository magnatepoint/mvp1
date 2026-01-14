# Fix Local Network Access Issue

## Problem
The app is getting "Local network prohibited" errors when trying to connect to the backend server at `192.168.68.104:8000`.

## Solution

### Option 1: Enable in iOS Settings (Recommended)

1. **Open iOS Settings** on your iPhone/iPad
2. Go to **Privacy & Security** → **Local Network**
3. Find **Monytix** in the list
4. **Toggle it ON** (enable it)

This will allow the app to access your local network.

### Option 2: Reinstall the App

Sometimes the permission prompt doesn't appear until you reinstall:

1. Delete the app from your device
2. Rebuild and install from Xcode
3. When you first try to connect, iOS should show a permission prompt
4. Tap **"Allow"** when prompted

### Option 3: Check Network Connection

Make sure:
- Your iPhone/iPad is on the **same Wi-Fi network** as your Mac
- Your Mac's IP address is still `192.168.68.104` (check with `./find-mac-ip.sh`)
- The backend server is running (`cd backend && ./start.sh`)

### Verification

After enabling local network access:
1. Open the app
2. Try to load data (e.g., go to SpendSense tab)
3. Check Xcode console - you should see successful API calls instead of "Local network prohibited" errors

## Technical Details

The app requires:
- `NSLocalNetworkUsageDescription` in Info.plist ✅ (already added)
- `NSAllowsLocalNetworking = true` in Info.plist ✅ (already added)
- User permission granted in iOS Settings ⚠️ (you need to do this)

The permission is **not automatic** - iOS requires explicit user consent for local network access for privacy reasons.


