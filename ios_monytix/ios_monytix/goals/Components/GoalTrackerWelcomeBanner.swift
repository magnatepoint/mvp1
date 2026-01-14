//
//  GoalTrackerWelcomeBanner.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalTrackerWelcomeBanner: View {
    let username: String?
    
    private var displayName: String {
        if let username = username {
            let name = username.components(separatedBy: "@").first ?? username
            return name.capitalized
        }
        return "User"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Flag icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "flag.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text("Turn dreams into reality. Smart goal tracking and AI insights.")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Welcome back, \(displayName)!")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.843, blue: 0.0), // #FFD700 (Gold/Yellow)
                    Color(red: 0.545, green: 0.361, blue: 0.965) // #8B5CF6 (Purple)
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
        GoalTrackerWelcomeBanner(username: "santosh@example.com")
        GoalTrackerWelcomeBanner(username: nil)
    }
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

