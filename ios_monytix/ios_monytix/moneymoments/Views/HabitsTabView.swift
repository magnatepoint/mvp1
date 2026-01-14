//
//  HabitsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct HabitsTabView: View {
    @ObservedObject var viewModel: MoneyMomentsViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    private let charcoalColor = Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Your Habits Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Habits")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                    
                    if viewModel.isMomentsLoading {
                        ProgressView()
                            .tint(goldColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else if let error = viewModel.momentsError {
                        errorState(error: error)
                    } else if viewModel.habits.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.habits) { habit in
                                HabitCard(habit: habit)
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
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No habits tracked yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Habits are derived from your spending moments. Compute moments to start tracking your habits.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                // Debug info
                VStack(spacing: 8) {
                    if !viewModel.moments.isEmpty {
                        Text("Found \(viewModel.moments.count) moments, but no habits created.")
                            .font(.system(size: 12))
                            .foregroundColor(.orange.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Text("This may indicate a transformation issue. Check console logs for details.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("No moments found in database.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Text("Make sure you have uploaded transaction data, then click the button below to compute moments for the past 12 months.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 4)
                
                Button(action: {
                    print("[MoneyMoments] ===== COMPUTE MOMENTS BUTTON CLICKED =====")
                    Task {
                        print("[MoneyMoments] Button task started")
                        // Compute moments for past year
                        let success = await viewModel.computeMomentsForPastYear()
                        print("[MoneyMoments] computeMomentsForPastYear returned: \(success)")
                        if success {
                            // Then reload all data
                            print("[MoneyMoments] Reloading all data after successful computation...")
                            await viewModel.loadAll()
                        } else {
                            print("[MoneyMoments] Computation failed, not reloading data")
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isComputing {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isComputing ? "Computing..." : "Compute Moments")
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
                .disabled(viewModel.isComputing)
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
}

#Preview {
    HabitsTabView(viewModel: MoneyMomentsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

