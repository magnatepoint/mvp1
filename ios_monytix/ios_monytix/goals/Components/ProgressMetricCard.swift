//
//  ProgressMetricCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct ProgressMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            VStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                }
                
                // Value
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Label
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ProgressMetricCard(
            icon: "flag.fill",
            value: "5",
            label: "Active Goals",
            color: Color(red: 0.545, green: 0.361, blue: 0.965) // Purple
        )
        
        ProgressMetricCard(
            icon: "checkmark.circle.fill",
            value: "3",
            label: "Completed",
            color: Color(red: 0.16, green: 0.725, blue: 0.506) // Green
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

