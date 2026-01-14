//
//  KPIDetailView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Charts

struct KPIDetailView: View {
    let kpiType: String
    let kpis: SpendSenseKPIs
    @Binding var isPresented: Bool
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Value Card
                    currentValueCard
                    
                    // Historical Chart (placeholder - would need historical data from API)
                    historicalChartCard
                    
                    // Breakdown Section
                    if let breakdown = getBreakdown() {
                        breakdownCard(breakdown)
                    }
                    
                    // Comparison Card
                    comparisonCard
                }
                .padding(20)
            }
            .background(Color(red: 0.18, green: 0.18, blue: 0.18))
            .navigationTitle(kpiTitle)
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
    
    // MARK: - Computed Properties
    
    private var kpiTitle: String {
        kpiType.capitalized
    }
    
    private var kpiValue: Double {
        switch kpiType.lowercased() {
        case "income":
            return kpis.incomeAmount ?? 0
        case "needs":
            return kpis.needsAmount ?? 0
        case "wants":
            return kpis.wantsAmount ?? 0
        case "assets":
            return kpis.assetsAmount ?? 0
        default:
            return 0
        }
    }
    
    private var kpiColor: Color {
        switch kpiType.lowercased() {
        case "income":
            return Color(red: 0.298, green: 0.686, blue: 0.314) // Green
        case "needs":
            return Color(red: 1.0, green: 0.596, blue: 0.0) // Orange
        case "wants":
            return Color(red: 0.612, green: 0.153, blue: 0.690) // Purple
        case "assets":
            return Color(red: 0.129, green: 0.588, blue: 0.953) // Blue
        default:
            return .gray
        }
    }
    
    private var kpiIcon: String {
        switch kpiType.lowercased() {
        case "income":
            return "arrow.up.circle.fill"
        case "needs":
            return "shield.fill"
        case "wants":
            return "shopping.bag.fill"
        case "assets":
            return "savings.fill"
        default:
            return "circle.fill"
        }
    }
    
    // MARK: - Views
    
    private var currentValueCard: some View {
        GlassCard(padding: 24, cornerRadius: 20) {
            VStack(spacing: 16) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        kpiColor.opacity(0.4),
                                        kpiColor.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: kpiIcon)
                            .foregroundColor(kpiColor)
                            .font(.system(size: 30, weight: .semibold))
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(kpiTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray.opacity(0.8))
                    
                    Text(formatCurrency(kpiValue))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var historicalChartCard: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Historical Trend")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Last 6 Months")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))
                
                // Placeholder chart - would need historical data from API
                Chart {
                    // Sample data for demonstration
                    ForEach(sampleHistoricalData, id: \.month) { data in
                        LineMark(
                            x: .value("Month", data.month),
                            y: .value("Value", data.value)
                        )
                        .foregroundStyle(kpiColor)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Month", data.month),
                            y: .value("Value", data.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [kpiColor.opacity(0.3), kpiColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                }
                
                Text("Note: Historical data requires API support")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
                    .italic()
            }
        }
    }
    
    private func breakdownCard(_ breakdown: [String: Double]) -> some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Breakdown")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(Array(breakdown.sorted(by: { $0.value > $1.value })), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text(formatCurrency(value))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.9))
                    }
                    .padding(.vertical, 8)
                    
                    if key != breakdown.keys.sorted(by: { breakdown[$0]! > breakdown[$1]! }).last {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
        }
    }
    
    private var comparisonCard: some View {
        GlassCard(padding: 20, cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Comparison")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    comparisonRow(
                        label: "This Month",
                        value: kpiValue,
                        color: kpiColor
                    )
                    
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    comparisonRow(
                        label: "Previous Month",
                        value: kpiValue * 0.95, // Placeholder - would come from API
                        color: .gray.opacity(0.6)
                    )
                    
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
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
    
    // MARK: - Helper Methods
    
    private func getBreakdown() -> [String: Double]? {
        // Placeholder - would get actual breakdown from API
        // For now, return top categories if available
        guard let topCategories = kpis.topCategories else { return nil }
        
        var breakdown: [String: Double] = [:]
        for category in topCategories.prefix(5) {
            let name = category.categoryName ?? category.categoryCode ?? "Unknown"
            breakdown[name] = category.spendAmount ?? 0
        }
        
        return breakdown.isEmpty ? nil : breakdown
    }
    
    private var sampleHistoricalData: [(month: String, value: Double)] {
        // Sample data for demonstration
        let baseValue = kpiValue
        return [
            (month: "Jul", value: baseValue * 0.85),
            (month: "Aug", value: baseValue * 0.90),
            (month: "Sep", value: baseValue * 0.88),
            (month: "Oct", value: baseValue * 0.92),
            (month: "Nov", value: baseValue * 0.95),
            (month: "Dec", value: baseValue)
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
    KPIDetailView(
        kpiType: "Income",
        kpis: SpendSenseKPIs(
            incomeAmount: 120000,
            needsAmount: 45000,
            wantsAmount: 30000,
            assetsAmount: 45000,
            wantsGauge: nil,
            topCategories: nil
        ),
        isPresented: .constant(true)
    )
}

