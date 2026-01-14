//
//  Config.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct Config {
    // Supabase configuration
    // For mobile and desktop apps, prefer using the publishable key (anon key)
    // You can get these from your Supabase project settings: Settings → API
    static let supabaseUrl = "https://vwagtikpxbhjrffolrqn.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ3YWd0aWtweGJoanJmZm9scnFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg3ODE0NDksImV4cCI6MjA3NDM1NzQ0OX0.cYevGkIj1HkjKv7iC14TgR7ItGF6YnXJi5Qw6ONYmcQ"
    
    // API configuration
    // For iOS Simulator: uses 127.0.0.1 (localhost)
    // For physical device: you need to set your Mac's local IP address
    // To find your Mac's IP: Run `./find-mac-ip.sh` in the ios_monytix directory
    // Or: `ifconfig | grep "inet " | grep -v 127.0.0.1` in Terminal
    // Note: This IP may change if you switch networks - update it if connection fails
    private static let deviceIPAddress = "192.168.68.104" // Your Mac's local IP (update if network changes)
    
    static var apiBaseUrl: String {
        return "https://api.monytix.ai"
    }
    
    // Helper to get connection instructions
    static var connectionInstructions: String {
        #if targetEnvironment(simulator)
        return """
        Using iOS Simulator - connecting to localhost.
        Make sure your backend server is running:
        cd backend && ./start.sh
        """
        #else
        return """
        Using physical device - connecting to \(deviceIPAddress):8000
        
        To connect your device:
        1. Make sure your Mac and iPhone are on the same Wi-Fi network
        2. Find your Mac's IP address: Run 'ifconfig | grep \"inet \" | grep -v 127.0.0.1' in Terminal
        3. Update 'deviceIPAddress' in Config.swift to match your Mac's IP
        4. Make sure your backend server is running: cd backend && ./start.sh
        5. Make sure your Mac's firewall allows connections on port 8000
        """
        #endif
    }
}

