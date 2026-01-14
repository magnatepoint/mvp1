//
//  SpendingTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct SpendingTabView: View {
    @ObservedObject var viewModel: MolyConsoleViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isSpendingLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if let error = viewModel.spendingError {
                    errorState(error)
                } else {
                    spendingContent
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadSpending()
        }
    }
    
    private var spendingContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // This Month's Spending
            VStack(alignment: .leading, spacing: 8) {
                Text("This Month's Spending")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray.opacity(0.7))
                
                Text(formatCurrency(viewModel.monthlySpending))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
            
            // Spending by Category
            if !viewModel.spendingByCategory.isEmpty {
                Text("Spending by Category")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(viewModel.spendingByCategory) { category in
                    CategorySpendingCard(category: category, totalSpending: viewModel.monthlySpending)
                }
            } else {
                emptyState
            }
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Spending")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadSpending()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Spending Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Upload statements to see your spending breakdown")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 40)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

// MARK: - Category Spending Card

struct CategorySpendingCard: View {
    let category: CategorySpending
    let totalSpending: Double
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(category.category)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatCurrency(category.amount))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(goldColor)
                                .frame(width: geometry.size.width * (category.percentage / 100), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text("\(String(format: "%.1f", category.percentage))%")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray.opacity(0.7))
                        .frame(width: 50, alignment: .trailing)
                }
                
                Text("\(category.transactionCount) transactions")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.6))
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

#Preview {
    let authService = AuthService()
    return SpendingTabView(viewModel: MolyConsoleViewModel(authService: authService))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

