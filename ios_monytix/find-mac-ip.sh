#!/bin/bash
# Helper script to find your Mac's local IP address for iOS device testing
# This IP should be set in Config.swift as deviceIPAddress

echo "Finding your Mac's local IP address..."
echo ""

# Try to find the primary network interface IP
IP=$(ifconfig | grep -E "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

if [ -z "$IP" ]; then
    echo "❌ Could not automatically detect IP address"
    echo ""
    echo "Please find your Mac's IP address manually:"
    echo "1. Open System Settings → Network"
    echo "2. Select your active connection (Wi-Fi or Ethernet)"
    echo "3. Look for the IP address (usually starts with 192.168.x.x or 10.x.x.x)"
    echo ""
    echo "Or run this command in Terminal:"
    echo "  ifconfig | grep 'inet ' | grep -v 127.0.0.1"
else
    echo "✅ Found IP address: $IP"
    echo ""
    echo "To use this IP in your iOS app:"
    echo "1. Open ios_monytix/ios_monytix/Config.swift"
    echo "2. Update the deviceIPAddress variable:"
    echo "   private static let deviceIPAddress = \"$IP\""
    echo ""
    echo "Note: Make sure your Mac and iPhone are on the same Wi-Fi network!"
fi

