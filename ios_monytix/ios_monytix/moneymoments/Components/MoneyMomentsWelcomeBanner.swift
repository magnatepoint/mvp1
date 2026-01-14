//
//  MoneyMomentsWelcomeBanner.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct MoneyMomentsWelcomeBanner: View {
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
            // Bell icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "bell.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Gentle reminders for smarter habits.")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Smart nudges and personalized prompts. Welcome back, \(displayName)!")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.843, blue: 0.0), // Yellow
                    Color(red: 1.0, green: 0.647, blue: 0.0)  // Orange
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VStack {
        MoneyMomentsWelcomeBanner(username: "santosh@example.com")
        MoneyMomentsWelcomeBanner(username: nil)
    }
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

