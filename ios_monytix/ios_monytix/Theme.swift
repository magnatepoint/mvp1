//
//  Theme.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct Theme {
    static let gold = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    static let charcoal = Color(red: 0.11, green: 0.11, blue: 0.11) // #1C1C1C (Darker)
    static let darkGray = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    static let lightText = Color.white.opacity(0.9)
    static let secondaryText = Color.white.opacity(0.6)
    
    // Gradients
    static let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.831, green: 0.686, blue: 0.216),
            Color(red: 1.0, green: 0.84, blue: 0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Corner Radius
    static let cornerRadius: CGFloat = 16
    
    // Shadows
    static func applyShadow(_ view: some View) -> some View {
        view.shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

// Reusable Components
struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadius)
            .fill(Theme.darkGray)
    }
}

extension View {
    func primaryButton() -> some View {
        self
            .font(.headline)
            .foregroundColor(.black)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.goldGradient)
            .cornerRadius(Theme.cornerRadius)
    }
}
