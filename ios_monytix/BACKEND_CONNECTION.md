# Backend Connection Setup

This guide explains how to connect the iOS app to the backend server.

## Quick Start

### For iOS Simulator
1. Make sure your backend is running: `cd backend && ./start.sh`
2. The app will automatically connect to `http://127.0.0.1:8000`
3. That's it! No configuration needed.

### For Physical Device
1. **Find your Mac's IP address:**
   ```bash
   cd ios_monytix
   ./find-mac-ip.sh
   ```
   Or manually: `ifconfig | grep "inet " | grep -v 127.0.0.1`

2. **Update Config.swift:**
   - Open `ios_monytix/ios_monytix/Config.swift`
   - Update the `deviceIPAddress` variable with your Mac's IP:
     ```swift
     private static let deviceIPAddress = "192.168.68.104" // Your Mac's IP
     ```

3. **Ensure same Wi-Fi network:**
   - Your Mac and iPhone must be on the same Wi-Fi network

4. **Start the backend:**
   ```bash
   cd backend
   ./start.sh
   ```

5. **Check firewall:**
   - Make sure your Mac's firewall allows connections on port 8000
   - System Settings → Network → Firewall → Options

## Troubleshooting

### "Could not connect to the server" Error

1. **Check backend is running:**
   ```bash
   curl http://127.0.0.1:8000/health
   # or
   curl http://YOUR_MAC_IP:8000/health
   ```

2. **For physical device:**
   - Verify Mac and iPhone are on the same Wi-Fi
   - Check the IP address in Config.swift matches your Mac's current IP
   - IP addresses can change when you switch networks

3. **Check firewall:**
   - macOS Firewall might be blocking port 8000
   - Temporarily disable firewall to test, or add an exception

4. **Test connection from device:**
   - Open Safari on your iPhone
   - Navigate to `http://YOUR_MAC_IP:8000/health`
   - If this doesn't work, the network configuration is the issue

### Network IP Changed

If you switch Wi-Fi networks, your Mac's IP address may change. Update `deviceIPAddress` in `Config.swift` with the new IP.

Run `./find-mac-ip.sh` again to get the new IP address.

## Configuration Details

The app automatically detects if it's running on:
- **iOS Simulator**: Uses `http://127.0.0.1:8000` (localhost)
- **Physical Device**: Uses `http://YOUR_MAC_IP:8000` (from Config.swift)

The configuration is in `ios_monytix/ios_monytix/Config.swift`:
```swift
static var apiBaseUrl: String {
    #if targetEnvironment(simulator)
    return "http://127.0.0.1:8000"
    #else
    return "http://\(deviceIPAddress):8000"
    #endif
}
```

## Security Note

The app is configured to allow HTTP connections to localhost and local network IPs for development. This is configured in `Info.plist` with `NSAllowsLocalNetworking = true`.

For production, you should:
1. Use HTTPS
2. Remove local network exceptions
3. Use a proper domain name

