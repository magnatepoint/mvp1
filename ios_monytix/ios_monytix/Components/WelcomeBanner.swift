//
//  WelcomeBanner.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct WelcomeBanner: View {
    let username: String?
    
    private var displayName: String {
        if let username = username {
            // Extract name from email (part before @) or use full email
            let name = username.components(separatedBy: "@").first ?? username
            return name.capitalized
        }
        return "User"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Bar chart icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("See where your money really goes.")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Automatically categorized insights. Welcome back, \(displayName)!")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Theme.goldGradient
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        WelcomeBanner(username: "santosh@example.com")
        WelcomeBanner(username: nil)
    }
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

