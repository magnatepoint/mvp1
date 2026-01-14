//
//  CategoryProgressBar.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct CategoryProgressBar: View {
    let categoryName: String
    let amount: Double
    let percentage: Double
    let transactionCount: Int
    let index: Int
    let onTap: (() -> Void)?
    
    @State private var animatedProgress: Double = 0
    @State private var isVisible = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    init(
        categoryName: String,
        amount: Double,
        percentage: Double,
        transactionCount: Int,
        index: Int,
        onTap: (() -> Void)? = nil
    ) {
        self.categoryName = categoryName
        self.amount = amount
        self.percentage = percentage
        self.transactionCount = transactionCount
        self.index = index
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap?()
        }) {
            GlassCard(padding: 20, cornerRadius: 16) {
                HStack(spacing: 16) {
                    // Category Icon
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
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: categoryIcon)
                            .foregroundColor(categoryColor)
                            .font(.system(size: 24, weight: .semibold))
                    }
                    
                    // Content
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        HStack {
                            Text(categoryName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(formatCurrency(amount))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 10)
                                
                                // Progress
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                categoryColor,
                                                categoryColor.opacity(0.7)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * animatedProgress, height: 10)
                                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animatedProgress)
                            }
                        }
                        .frame(height: 10)
                        
                        // Footer
                        HStack {
                            Text("\(String(format: "%.1f", percentage))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray.opacity(0.7))
                            
                            Text("•")
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("\(transactionCount) transactions")
                                .font(.system(size: 13))
                                .foregroundColor(.gray.opacity(0.7))
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
            }
            .frame(minHeight: 80)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .onAppear {
            let delay = Double(index) * 0.05
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                isVisible = true
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(delay + 0.1)) {
                animatedProgress = percentage / 100
            }
        }
        .onChange(of: percentage) { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = newValue / 100
            }
        }
    }
    
    // MARK: - Category Helpers
    
    private var categoryColor: Color {
        // Assign colors based on category name
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
    
    private var categoryIcon: String {
        // Assign icons based on category name
        let name = categoryName.lowercased()
        if name.contains("food") || name.contains("dining") || name.contains("restaurant") {
            return "fork.knife"
        } else if name.contains("shopping") || name.contains("retail") {
            return "bag.fill"
        } else if name.contains("transport") || name.contains("travel") {
            return "car.fill"
        } else if name.contains("entertainment") || name.contains("recreation") {
            return "tv.fill"
        } else if name.contains("bills") || name.contains("utilities") {
            return "bolt.fill"
        } else {
            return "folder.fill"
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

#Preview {
    VStack(spacing: 16) {
        CategoryProgressBar(
            categoryName: "Food & Dining",
            amount: 15000,
            percentage: 35.5,
            transactionCount: 42,
            index: 0
        )
        
        CategoryProgressBar(
            categoryName: "Shopping",
            amount: 8500,
            percentage: 20.2,
            transactionCount: 18,
            index: 1
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

