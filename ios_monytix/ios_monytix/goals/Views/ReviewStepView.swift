//
//  ReviewStepView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct ReviewStepView: View {
    @ObservedObject var viewModel: GoalsViewModel
    let onComplete: () -> Void
    
    @State private var isSubmitting = false
    @State private var showSuccess = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review & Submit")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Review your goals and life context before submitting.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if showSuccess {
                    successView
                } else {
                    // Life Context Summary
                    if let context = viewModel.lifeContext {
                        GlassCard(padding: 20, cornerRadius: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Life Context")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    InfoRow(label: "Age Range", value: context.ageBand)
                                    InfoRow(label: "Employment", value: context.employment.capitalized)
                                    InfoRow(label: "Housing", value: context.housing.replacingOccurrences(of: "_", with: " ").capitalized)
                                    InfoRow(label: "Income", value: context.incomeRegularity.replacingOccurrences(of: "_", with: " ").capitalized)
                                    InfoRow(label: "Region", value: IndianState.displayName(for: context.regionCode))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Goals Summary
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Selected Goals (\(viewModel.selectedGoals.count))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ForEach(Array(viewModel.selectedGoals.enumerated()), id: \.element.id) { index, goal in
                            GlassCard(padding: 16, cornerRadius: 16) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(goal.goalName)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(index + 1)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(goldColor)
                                            .padding(6)
                                            .background(goldColor.opacity(0.2))
                                            .clipShape(Circle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        InfoRow(label: "Category", value: goal.goalCategory)
                                        InfoRow(label: "Target Amount", value: formatCurrency(goal.estimatedCost))
                                        
                                        if let targetDate = goal.targetDate {
                                            InfoRow(label: "Target Date", value: formatDate(targetDate))
                                        }
                                        
                                        if goal.currentSavings > 0 {
                                            InfoRow(label: "Current Savings", value: formatCurrency(goal.currentSavings))
                                        }
                                        
                                        InfoRow(label: "Importance", value: "\(goal.importance)/5")
                                        
                                        if let notes = goal.notes, !notes.isEmpty {
                                            Text("Notes: \(notes)")
                                                .font(.system(size: 13))
                                                .foregroundColor(.gray.opacity(0.7))
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Submit Button
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await submitGoals()
                            }
                        }) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                }
                                
                                Text(isSubmitting ? "Submitting..." : "Submit Goals")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(goldColor)
                            .cornerRadius(12)
                        }
                        .disabled(isSubmitting || viewModel.selectedGoals.isEmpty)
                        
                        Button(action: {
                            viewModel.previousStep()
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private var successView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Goals Submitted Successfully!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Your financial goals have been saved. You can now track your progress.")
                .font(.system(size: 16))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: onComplete) {
                Text("Continue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(goldColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .padding(.top, 60)
    }
    
    private func submitGoals() async {
        guard let context = viewModel.lifeContext else { return }
        
        isSubmitting = true
        defer { isSubmitting = false }
        
        let success = await viewModel.submitGoals(context: context)
        
        if success {
            withAnimation {
                showSuccess = true
            }
            
            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onComplete()
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ReviewStepView(viewModel: GoalsViewModel(authService: AuthService())) {
        print("Complete")
    }
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

