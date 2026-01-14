//
//  GoalsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalsTabView: View {
    @ObservedObject var viewModel: MolyConsoleViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isGoalsLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if let error = viewModel.goalsError {
                    errorState(error)
                } else if viewModel.goals.isEmpty {
                    emptyState
                } else {
                    goalsContent
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadGoals()
        }
    }
    
    private var goalsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Financial Goals")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(viewModel.goals.filter { $0.isActive }) { goal in
                GoalCard(goal: goal)
            }
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Goals")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadGoals()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Goals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Create financial goals to track your progress")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.purple)
                    
                    Text(goal.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                // Amounts
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Text(formatCurrency(goal.savedAmount))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        Text(formatCurrency(goal.targetAmount))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(String(format: "%.1f", goal.progressPercentage))% Complete")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(goldColor)
                        
                        Spacer()
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 12)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [goldColor, goldColor.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * goal.progress, height: 12)
                        }
                    }
                    .frame(height: 12)
                    
                    Text("₹\(formatNumber(goal.remainingAmount)) remaining")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.6))
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
    
    private func formatNumber(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "0"
    }
}

#Preview {
    let authService = AuthService()
    return GoalsTabView(viewModel: MolyConsoleViewModel(authService: authService))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

