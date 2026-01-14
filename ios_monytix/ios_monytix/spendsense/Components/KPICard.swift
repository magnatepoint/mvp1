//
//  KPICard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct KPICard: View {
    let label: String
    let value: Double
    let icon: String
    let color: Color
    let index: Int
    let trendChange: Double? // Month-over-month percentage change
    let onTap: (() -> Void)?
    
    @State private var animatedValue: Double = 0
    @State private var isVisible = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    init(
        label: String,
        value: Double,
        icon: String,
        color: Color,
        index: Int,
        trendChange: Double? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.icon = icon
        self.color = color
        self.index = index
        self.trendChange = trendChange
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onTap?()
        }) {
            GlassCard(padding: 20, cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with icon and trend
                    HStack {
                        // Icon with gradient background
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.4),
                                            color.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: icon)
                                .foregroundColor(color)
                                .font(.system(size: 24, weight: .semibold))
                        }
                        
                        Spacer()
                        
                        // Trend indicator
                        if let trend = trendChange {
                            TrendBadge(change: trend)
                        }
                    }
                    
                    Spacer()
                    
                    // Value
                    Text(formatCurrency(animatedValue))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    // Label and quick insight
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.gray.opacity(0.8))
                        
                        if let insight = quickInsight {
                            Text(insight)
                                .font(.system(size: 12))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                }
                .frame(minHeight: 120)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(Double(index) * 0.1)) {
                isVisible = true
            }
            
            // Animate value counting up
            withAnimation(.easeOut(duration: 1.0).delay(Double(index) * 0.1 + 0.2)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = newValue
            }
        }
    }
    
    private var quickInsight: String? {
        // Generate quick insights based on KPI type and value
        switch label.lowercased() {
        case "income":
            if value > 100000 {
                return "Strong income stream"
            }
        case "needs":
            if let trend = trendChange, trend > 10 {
                return "Needs spending increased"
            }
        case "wants":
            if let trend = trendChange, trend > 15 {
                return "Wants spending rising"
            }
        case "assets":
            if value > 50000 {
                return "Good asset growth"
            }
        default:
            break
        }
        return nil
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let change: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))
            
            Text("\(abs(change), specifier: "%.1f")%")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(change >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
        )
        .overlay(
            Capsule()
                .stroke(change >= 0 ? Color.green : Color.red, lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        KPICard(
            label: "Income",
            value: 125000,
            icon: "arrow.up.circle.fill",
            color: Color(red: 0.298, green: 0.686, blue: 0.314),
            index: 0
        )
        
        KPICard(
            label: "Needs",
            value: 45000,
            icon: "shield.fill",
            color: Color(red: 1.0, green: 0.596, blue: 0.0),
            index: 1
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

