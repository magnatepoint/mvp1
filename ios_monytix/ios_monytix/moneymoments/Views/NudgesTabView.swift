//
//  NudgesTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct NudgesTabView: View {
    @ObservedObject var viewModel: MoneyMomentsViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Progress Metrics Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Progress")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    // Progress metrics grid
                    HStack(spacing: 12) {
                        // Streak
                        MoneyMomentsProgressMetricCard(
                            icon: "flame.fill",
                            value: "\(viewModel.progressMetrics.streak) days",
                            label: "Streak",
                            color: .red
                        )
                        
                        // Nudges
                        MoneyMomentsProgressMetricCard(
                            icon: "bell.fill",
                            value: "\(viewModel.progressMetrics.nudgesCount)",
                            label: "Nudges",
                            color: .blue
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        // Habits
                        MoneyMomentsProgressMetricCard(
                            icon: "checkmark.circle.fill",
                            value: "\(viewModel.progressMetrics.habitsCount)",
                            label: "Habits",
                            color: .green
                        )
                        
                        // Saved
                        MoneyMomentsProgressMetricCard(
                            icon: "banknote.fill",
                            value: formatCurrency(viewModel.progressMetrics.savedAmount),
                            label: "Saved",
                            color: Color(red: 0.6, green: 0.4, blue: 0.2) // Brown
                        )
                    }
                    .padding(.horizontal, 20)
                }
                
                // Active Nudges Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Active Nudges")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    if viewModel.isNudgesLoading {
                        ProgressView()
                            .tint(goldColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if let error = viewModel.nudgesError {
                        errorState(error: error)
                    } else if viewModel.nudges.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.nudges) { nudge in
                                NudgeCard(nudge: nudge) { deliveryId, eventType in
                                    Task {
                                        await viewModel.logNudgeInteraction(
                                            deliveryId: deliveryId,
                                            eventType: eventType
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(charcoalColor)
    }
    
    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No active nudges")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Nudges are personalized recommendations based on your spending. Evaluate and deliver nudges to get started.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // Debug info
                VStack(spacing: 8) {
                    Text("Current nudges count: \(viewModel.nudges.count)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    if viewModel.nudges.isEmpty {
                        Text("The evaluation process will analyze your spending patterns and create personalized recommendations.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 4)
                
                Button(action: {
                    Task {
                        let success = await viewModel.evaluateAndDeliverNudges()
                        if success {
                            // Reload nudges
                            await viewModel.loadNudges(limit: 200)
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isEvaluating || viewModel.isProcessing {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bell.badge")
                        }
                        Text(viewModel.isEvaluating || viewModel.isProcessing ? "Processing..." : "Evaluate & Deliver Nudges")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(goldColor)
                    )
                    .foregroundColor(.black)
                }
                .disabled(viewModel.isEvaluating || viewModel.isProcessing)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
        }
    }
    
    private func errorState(error: String) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Error")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
    }
}

#Preview {
    NudgesTabView(viewModel: MoneyMomentsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

