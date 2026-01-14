//
//  CategoryDetailView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Charts

struct CategoryDetailView: View {
    let category: CategoryBreakdown
    @Binding var isPresented: Bool
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Category Header
                    categoryHeader
                    
                    // Stats Overview
                    statsOverview
                    
                    // Trend Chart (placeholder)
                    trendChart
                    
                    // Comparison
                    comparisonSection
                }
                .padding(20)
            }
            .background(Color(red: 0.18, green: 0.18, blue: 0.18))
            .navigationTitle(category.categoryName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(goldColor)
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var categoryHeader: some View {
        GlassCard(padding: 24, cornerRadius: 20) {
            VStack(spacing: 16) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        categoryColor.opacity(0.4),
                                        categoryColor.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: categoryIcon)
                            .foregroundColor(categoryColor)
                            .font(.system(size: 30, weight: .semibold))
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Spending")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                    
                    Text(formatCurrency(category.amount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var statsOverview: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Overview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    statRow(label: "Percentage of Total", value: "\(String(format: "%.1f", category.percentage))%")
                    Divider().background(Color.gray.opacity(0.2))
                    statRow(label: "Transaction Count", value: "\(category.transactionCount)")
                    Divider().background(Color.gray.opacity(0.2))
                    statRow(label: "Average per Transaction", value: formatCurrency(category.amount / Double(category.transactionCount)))
                }
            }
        }
    }
    
    private var trendChart: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Trend")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Last 6 Months")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))
                
                // Placeholder chart
                Chart {
                    ForEach(sampleTrendData, id: \.month) { data in
                        LineMark(
                            x: .value("Month", data.month),
                            y: .value("Amount", data.amount)
                        )
                        .foregroundStyle(categoryColor)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel().foregroundStyle(.gray.opacity(0.7))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel().foregroundStyle(.gray.opacity(0.7))
                    }
                }
                
                Text("Note: Historical data requires API support")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
                    .italic()
            }
        }
    }
    
    private var comparisonSection: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Comparison")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    comparisonRow(label: "This Month", value: category.amount, color: categoryColor)
                    Divider().background(Color.gray.opacity(0.2))
                    comparisonRow(label: "Previous Month", value: category.amount * 0.95, color: .gray.opacity(0.6))
                    Divider().background(Color.gray.opacity(0.2))
                    HStack {
                        Text("Change")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .bold))
                            Text("5.0%")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.gray.opacity(0.9))
        }
    }
    
    private func comparisonRow(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            Spacer()
            Text(formatCurrency(value))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
    }
    
    // MARK: - Helpers
    
    private var categoryColor: Color {
        let name = category.categoryName.lowercased()
        if name.contains("food") || name.contains("dining") {
            return Color(red: 1.0, green: 0.596, blue: 0.0)
        } else if name.contains("shopping") {
            return Color(red: 0.612, green: 0.153, blue: 0.690)
        } else if name.contains("transport") {
            return Color(red: 0.129, green: 0.588, blue: 0.953)
        } else {
            return goldColor
        }
    }
    
    private var categoryIcon: String {
        let name = category.categoryName.lowercased()
        if name.contains("food") || name.contains("dining") {
            return "fork.knife"
        } else if name.contains("shopping") {
            return "bag.fill"
        } else if name.contains("transport") {
            return "car.fill"
        } else {
            return "folder.fill"
        }
    }
    
    private var sampleTrendData: [(month: String, amount: Double)] {
        let baseAmount = category.amount
        return [
            (month: "Jul", amount: baseAmount * 0.85),
            (month: "Aug", amount: baseAmount * 0.90),
            (month: "Sep", amount: baseAmount * 0.88),
            (month: "Oct", amount: baseAmount * 0.92),
            (month: "Nov", amount: baseAmount * 0.95),
            (month: "Dec", amount: baseAmount)
        ]
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

#Preview {
    CategoryDetailView(
        category: CategoryBreakdown(
            categoryName: "Food & Dining",
            amount: 15000,
            percentage: 35.5,
            transactionCount: 42
        ),
        isPresented: .constant(true)
    )
}

