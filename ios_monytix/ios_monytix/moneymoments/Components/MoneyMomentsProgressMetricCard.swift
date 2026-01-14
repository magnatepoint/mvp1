//
//  MoneyMomentsProgressMetricCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct MoneyMomentsProgressMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(color)
                
                // Value
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Label
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        MoneyMomentsProgressMetricCard(
            icon: "flame.fill",
            value: "12 days",
            label: "Streak",
            color: .red
        )
        
        MoneyMomentsProgressMetricCard(
            icon: "bell.fill",
            value: "45",
            label: "Nudges",
            color: .blue
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

