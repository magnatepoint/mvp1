//
//  CategoryDonutChart.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Charts

struct CategoryDonutChart: View {
    let categories: [CategoryBreakdown]
    let subcategories: [SubcategoryBreakdown]?
    let onCategorySelected: ((CategoryBreakdown) -> Void)?
    let onCategoryTapped: ((CategoryBreakdown?) -> Void)?
    
    @State private var selectedCategory: CategoryBreakdown?
    @State private var isVisible = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let chartSize: CGFloat = 280
    private let subcategoryChartSize: CGFloat = 200
    
    init(
        categories: [CategoryBreakdown],
        subcategories: [SubcategoryBreakdown]? = nil,
        onCategorySelected: ((CategoryBreakdown) -> Void)? = nil,
        onCategoryTapped: ((CategoryBreakdown?) -> Void)? = nil
    ) {
        self.categories = categories
        self.subcategories = subcategories
        self.onCategorySelected = onCategorySelected
        self.onCategoryTapped = onCategoryTapped
    }
    
    var body: some View {
        GlassCard(padding: 24, cornerRadius: 20) {
            if categories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No category data available")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(height: chartSize)
            } else {
                VStack(spacing: 24) {
                    // Chart and Legend
                    HStack(spacing: 24) {
                        // Donut Chart
                        ZStack {
                        Chart {
                            ForEach(chartData) { item in
                                SectorMark(
                                    angle: .value("Amount", item.value),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 3
                                )
                                .foregroundStyle(item.color)
                                .opacity(selectedCategory?.categoryName == item.categoryName ? 1.0 : (selectedCategory == nil ? 1.0 : 0.4))
                                .cornerRadius(4)
                            }
                        }
                        .frame(width: chartSize, height: chartSize)
                        .contentShape(Rectangle())
                        .gesture(
                            TapGesture()
                                .onEnded { _ in
                                    // Cycle through categories on tap, or deselect if already selected
                                    if let current = selectedCategory,
                                       let currentIndex = categories.firstIndex(where: { $0.categoryName == current.categoryName }) {
                                        let nextIndex = (currentIndex + 1) % categories.count
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if nextIndex == 0 {
                                                selectedCategory = nil
                                                onCategoryTapped?(nil)
                                            } else {
                                                selectedCategory = categories[nextIndex]
                                                onCategoryTapped?(categories[nextIndex])
                                            }
                                        }
                                    } else if !categories.isEmpty {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = categories[0]
                                            onCategoryTapped?(categories[0])
                                        }
                                    }
                                    
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    if let selected = selectedCategory {
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                        onCategorySelected?(selected)
                                    }
                                }
                        )
                        
                        // Center content
                        VStack(spacing: 4) {
                            if let selected = selectedCategory {
                                Text(selected.categoryName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                
                                Text(formatCurrency(selected.amount))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(String(format: "%.1f", selected.percentage))%")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.8))
                                
                                Text("Long press for details")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 2)
                            } else {
                                Text("Total")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.7))
                                
                                Text(formatCurrency(totalAmount))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("\(categories.count) categories")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                                
                                Text("Tap to explore")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 2)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedCategory?.id)
                        .allowsHitTesting(false) // Don't intercept touches
                        }
                        
                        // Legend
                        ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(chartData) { item in
                                LegendItem(
                                    category: item.categoryName,
                                    amount: item.value,
                                    percentage: item.percentage,
                                    color: item.color,
                                    isSelected: selectedCategory?.categoryName == item.categoryName,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            if selectedCategory?.categoryName == item.categoryName {
                                                selectedCategory = nil
                                                onCategoryTapped?(nil)
                                            } else {
                                                selectedCategory = categories.first { $0.categoryName == item.categoryName }
                                                onCategoryTapped?(selectedCategory)
                                            }
                                        }
                                        
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: chartSize)
                }
                
                // Subcategory Donut Chart (shown when category is selected)
                if let selected = selectedCategory,
                   let subcategories = subcategories,
                   !subcategories.isEmpty {
                    VStack(spacing: 16) {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.vertical, 8)
                        
                        // Subcategory Header
                        HStack {
                            Text("\(selected.categoryName) - Subcategories")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        
                        // Subcategory Donut Chart
                        HStack(spacing: 20) {
                            // Subcategory Chart
                            ZStack {
                                Chart {
                                    ForEach(subcategoryChartData) { item in
                                        SectorMark(
                                            angle: .value("Amount", item.value),
                                            innerRadius: .ratio(0.6),
                                            angularInset: 2
                                        )
                                        .foregroundStyle(item.color)
                                        .cornerRadius(3)
                                    }
                                }
                                .frame(width: subcategoryChartSize, height: subcategoryChartSize)
                                
                                // Center content
                                VStack(spacing: 4) {
                                    Text("Subcategories")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.gray.opacity(0.7))
                                    
                                    Text("\(subcategories.count)")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .allowsHitTesting(false)
                            }
                            
                            // Subcategory Legend
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(subcategories.prefix(8)) { subcategory in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(subcategoryColor(for: subcategory.subcategoryName))
                                                .frame(width: 10, height: 10)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(subcategory.subcategoryName)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                
                                                Text("\(String(format: "%.1f", subcategory.percentage))%")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.gray.opacity(0.7))
                                            }
                                            
                                            Spacer()
                                            
                                            Text(formatCurrency(subcategory.amount))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .frame(maxHeight: subcategoryChartSize)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var chartData: [CategoryChartData] {
        return categories.map { category in
            CategoryChartData(
                categoryName: category.categoryName,
                value: category.amount,
                percentage: category.percentage,
                color: categoryColor(for: category.categoryName)
            )
        }
    }
    
    private var totalAmount: Double {
        categories.reduce(0) { $0 + $1.amount }
    }
    
    private var subcategoryChartData: [CategoryChartData] {
        guard let subcategories = subcategories else { return [] }
        return subcategories.map { subcategory in
            CategoryChartData(
                categoryName: subcategory.subcategoryName,
                value: subcategory.amount,
                percentage: subcategory.percentage,
                color: subcategoryColor(for: subcategory.subcategoryName)
            )
        }
    }
    
    private func categoryColor(for categoryName: String) -> Color {
        let name = categoryName.lowercased()
        if name.contains("food") || name.contains("dining") || name.contains("restaurant") {
            return Color(red: 1.0, green: 0.596, blue: 0.0) // Orange
        } else if name.contains("shopping") || name.contains("retail") {
            return Color(red: 0.612, green: 0.153, blue: 0.690) // Purple
        } else if name.contains("transport") || name.contains("travel") {
            return Color(red: 0.129, green: 0.588, blue: 0.953) // Blue
        } else if name.contains("entertainment") || name.contains("recreation") {
            return Color(red: 0.957, green: 0.263, blue: 0.212) // Red
        } else if name.contains("bills") || name.contains("utilities") {
            return Color(red: 0.298, green: 0.686, blue: 0.314) // Green
        } else {
            return goldColor
        }
    }
    
    private func subcategoryColor(for subcategoryName: String) -> Color {
        let name = subcategoryName.lowercased()
        // Use lighter variations of category colors
        if name.contains("food") || name.contains("dining") || name.contains("restaurant") || name.contains("grocery") {
            return Color(red: 1.0, green: 0.596, blue: 0.0).opacity(0.8) // Orange
        } else if name.contains("shopping") || name.contains("retail") || name.contains("store") {
            return Color(red: 0.612, green: 0.153, blue: 0.690).opacity(0.8) // Purple
        } else if name.contains("transport") || name.contains("travel") || name.contains("uber") || name.contains("taxi") {
            return Color(red: 0.129, green: 0.588, blue: 0.953).opacity(0.8) // Blue
        } else if name.contains("entertainment") || name.contains("recreation") || name.contains("movie") {
            return Color(red: 0.957, green: 0.263, blue: 0.212).opacity(0.8) // Red
        } else if name.contains("bills") || name.contains("utilities") || name.contains("electricity") || name.contains("water") {
            return Color(red: 0.298, green: 0.686, blue: 0.314).opacity(0.8) // Green
        } else {
            return goldColor.opacity(0.8)
        }
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

// MARK: - Category Chart Data

struct CategoryChartData: Identifiable {
    let id = UUID()
    let categoryName: String
    let value: Double
    let percentage: Double
    let color: Color
}

// MARK: - Legend Item

struct LegendItem: View {
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Color indicator
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                
                // Category info
                VStack(alignment: .leading, spacing: 2) {
                    Text(category)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(String(format: "%.1f", percentage))%")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                Spacer()
                
                // Amount
                Text(formatCurrency(amount))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isSelected ? 1.0 : 0.7)
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
    CategoryDonutChart(
        categories: [
            CategoryBreakdown(
                categoryName: "Food & Dining",
                amount: 15000,
                percentage: 35.5,
                transactionCount: 42
            ),
            CategoryBreakdown(
                categoryName: "Shopping",
                amount: 8500,
                percentage: 20.2,
                transactionCount: 18
            ),
            CategoryBreakdown(
                categoryName: "Transport",
                amount: 6000,
                percentage: 14.3,
                transactionCount: 25
            ),
            CategoryBreakdown(
                categoryName: "Entertainment",
                amount: 4500,
                percentage: 10.7,
                transactionCount: 12
            )
        ],
        subcategories: [
            SubcategoryBreakdown(
                subcategoryName: "Restaurants",
                amount: 8000,
                percentage: 53.3,
                transactionCount: 25
            ),
            SubcategoryBreakdown(
                subcategoryName: "Groceries",
                amount: 5000,
                percentage: 33.3,
                transactionCount: 15
            ),
            SubcategoryBreakdown(
                subcategoryName: "Fast Food",
                amount: 2000,
                percentage: 13.4,
                transactionCount: 12
            )
        ]
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

