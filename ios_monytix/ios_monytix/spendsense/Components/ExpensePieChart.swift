//
//  ExpensePieChart.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Charts

struct ExpensePieChart: View {
    let data: [ChartData]
    let size: CGFloat
    let title: String
    let subtitle: String
    
    @State private var selectedSegment: ChartData?
    @State private var isVisible = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                // Chart
                HStack(spacing: 30) {
                    // Pie Chart
                    Chart {
                        ForEach(data) { item in
                            SectorMark(
                                angle: .value("Amount", item.value),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(item.color.swiftUIColor)
                            .opacity(selectedSegment?.label == item.label ? 1.0 : (selectedSegment == nil ? 1.0 : 0.5))
                            .cornerRadius(4)
                        }
                    }
                    .frame(width: size, height: size)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(data) { item in
                            HStack(spacing: 8) {
                                // Color indicator
                                Circle()
                                    .fill(item.color.swiftUIColor)
                                    .frame(width: 12, height: 12)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.label)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text(formatPercentage(item.value, total: totalValue))
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Text(formatCurrency(item.value))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .opacity(selectedSegment?.label == item.label ? 1.0 : (selectedSegment == nil ? 1.0 : 0.5))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedSegment = selectedSegment?.label == item.label ? nil : item
                                }
                            }
                        }
                    }
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isVisible = true
            }
        }
    }
    
    private var totalValue: Double {
        data.reduce(0) { $0 + $1.value }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
    
    private func formatPercentage(_ value: Double, total: Double) -> String {
        guard total > 0 else { return "0%" }
        let percentage = (value / total) * 100
        return String(format: "%.1f%%", percentage)
    }
}

#Preview {
    ExpensePieChart(
        data: [
            ChartData(label: "Needs", value: 45000, color: .green),
            ChartData(label: "Wants", value: 25000, color: .orange),
            ChartData(label: "Savings", value: 55000, color: .blue)
        ],
        size: 180,
        title: "Expense Breakdown",
        subtitle: "Spending by category"
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

