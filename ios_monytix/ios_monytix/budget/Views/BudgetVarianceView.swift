//
//  BudgetVarianceView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct BudgetVarianceView: View {
    @ObservedObject var viewModel: BudgetViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Budget Variance")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Compare your actual spending with your planned budget")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if viewModel.isVarianceLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if let error = viewModel.varianceError {
                    errorState(error)
                } else if let variance = viewModel.variance {
                    varianceContent(variance)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadVariance()
        }
    }
    
    private func varianceContent(_ variance: BudgetVariance) -> some View {
        VStack(spacing: 20) {
            // Income
            VarianceCard(
                title: "Income",
                actual: variance.incomeAmt,
                planned: variance.incomeAmt,
                variance: 0,
                color: .green
            )
            .padding(.horizontal, 20)
            
            // Needs
            VarianceCard(
                title: "Needs",
                actual: variance.needsAmt,
                planned: variance.plannedNeedsAmt,
                variance: variance.varianceNeedsAmt,
                color: .blue
            )
            .padding(.horizontal, 20)
            
            // Wants
            VarianceCard(
                title: "Wants",
                actual: variance.wantsAmt,
                planned: variance.plannedWantsAmt,
                variance: variance.varianceWantsAmt,
                color: .orange
            )
            .padding(.horizontal, 20)
            
            // Assets/Savings
            VarianceCard(
                title: "Savings",
                actual: variance.assetsAmt,
                planned: variance.plannedAssetsAmt,
                variance: variance.varianceAssetsAmt,
                color: .green
            )
            .padding(.horizontal, 20)
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Variance")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadVariance()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 40)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Variance Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Variance data will appear here once you have a committed budget and spending data.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

// MARK: - Variance Card

struct VarianceCard: View {
    let title: String
    let actual: Double
    let planned: Double
    let variance: Double
    let color: Color
    
    private var isOverBudget: Bool {
        variance < 0
    }
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Actual vs Planned
                VStack(spacing: 12) {
                    HStack {
                        Text("Actual")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Spacer()
                        
                        Text(formatCurrency(actual))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    HStack {
                        Text("Planned")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Spacer()
                        
                        Text(formatCurrency(planned))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                // Variance
                HStack {
                    Text("Variance")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: isOverBudget ? "arrow.up" : "arrow.down")
                            .font(.system(size: 12, weight: .bold))
                        
                        Text(formatCurrency(abs(variance)))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(isOverBudget ? .red : .green)
                }
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
    BudgetVarianceView(viewModel: BudgetViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

