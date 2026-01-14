//
//  GoalDetailStepView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalDetailStepView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    @State private var estimatedCost: String = ""
    @State private var targetDate: Date = Date()
    @State private var hasTargetDate: Bool = false
    @State private var currentSavings: String = "0"
    @State private var importance: Double = 3
    @State private var notes: String = ""
    
    @State private var errors: [String: String] = [:]
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    private var currentGoal: SelectedGoal? {
        guard viewModel.currentGoalIndex < viewModel.selectedGoals.count else { return nil }
        return viewModel.selectedGoals[viewModel.currentGoalIndex]
    }
    
    private var catalogItem: GoalCatalogItem? {
        guard let goal = currentGoal else { return nil }
        return viewModel.catalog.first { $0.goalCategory == goal.goalCategory && $0.goalName == goal.goalName }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Goal Details")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let goal = currentGoal {
                        Text("\(goal.goalName) (\(viewModel.currentGoalIndex + 1) of \(viewModel.selectedGoals.count))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(goldColor)
                    }
                    
                    Text("Set targets and priorities for your goal.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if currentGoal != nil {
                    // Form
                    VStack(spacing: 20) {
                        // Estimated Cost
                        FormField(
                            title: "Estimated Cost (₹) *",
                            error: errors["estimated_cost"]
                        ) {
                            TextField("Enter target amount", text: $estimatedCost)
                                .keyboardType(.decimalPad)
                                .foregroundColor(.white)
                        }
                        
                        // Target Date
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Set Target Date", isOn: $hasTargetDate)
                                .foregroundColor(.white)
                            
                            if hasTargetDate {
                                DatePicker(
                                    "Target Date",
                                    selection: $targetDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)
                                .foregroundColor(.white)
                            }
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Current Savings
                        FormField(
                            title: "Current Savings (₹)",
                            error: nil
                        ) {
                            TextField("Enter current savings", text: $currentSavings)
                                .keyboardType(.decimalPad)
                                .foregroundColor(.white)
                        }
                        
                        // Importance
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Importance")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.7))
                                
                                Spacer()
                                
                                Text("\(Int(importance))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(goldColor)
                            }
                            
                            Slider(value: $importance, in: 1...5, step: 1)
                                .tint(goldColor)
                            
                            HStack {
                                Text("Low")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                                Spacer()
                                Text("High")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Notes
                        FormField(
                            title: "Notes (Optional)",
                            error: nil
                        ) {
                            TextField("Add any notes about this goal", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Navigation Buttons
                    HStack(spacing: 16) {
                        if viewModel.currentGoalIndex > 0 {
                            Button(action: {
                                saveCurrentGoal()
                                viewModel.previousGoal()
                                loadGoalData()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("Previous")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(12)
                            }
                        }
                        
                        Spacer()
                        
                        if viewModel.currentGoalIndex < viewModel.selectedGoals.count - 1 {
                            Button(action: {
                                saveCurrentGoal()
                                viewModel.nextGoal()
                                loadGoalData()
                            }) {
                                HStack {
                                    Text("Next Goal")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(goldColor)
                                .cornerRadius(12)
                            }
                        } else {
                            Button(action: {
                                if validate() {
                                    saveCurrentGoal()
                                    viewModel.nextStep()
                                }
                            }) {
                                HStack {
                                    Text("Review")
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(goldColor)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            loadGoalData()
        }
    }
    
    private func loadGoalData() {
        guard let goal = currentGoal else { return }
        
        estimatedCost = goal.estimatedCost > 0 ? String(format: "%.0f", goal.estimatedCost) : ""
        targetDate = goal.targetDate ?? defaultTargetDate()
        hasTargetDate = goal.targetDate != nil
        currentSavings = goal.currentSavings > 0 ? String(format: "%.0f", goal.currentSavings) : "0"
        importance = Double(goal.importance)
        notes = goal.notes ?? ""
    }
    
    private func defaultTargetDate() -> Date {
        let calendar = Calendar.current
        var date = Date()
        
        if let catalogItem = catalogItem {
            switch catalogItem.defaultHorizon {
            case "short_term":
                date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
            case "medium_term":
                date = calendar.date(byAdding: .year, value: 3, to: date) ?? date
            case "long_term":
                date = calendar.date(byAdding: .year, value: 7, to: date) ?? date
            default:
                break
            }
        }
        
        return date
    }
    
    private func validate() -> Bool {
        errors = [:]
        
        if estimatedCost.isEmpty || Double(estimatedCost) ?? 0 <= 0 {
            errors["estimated_cost"] = "Estimated cost must be greater than 0"
        }
        
        if importance < 1 || importance > 5 {
            errors["importance"] = "Importance must be between 1 and 5"
        }
        
        return errors.isEmpty
    }
    
    private func saveCurrentGoal() {
        guard let goal = currentGoal,
              let cost = Double(estimatedCost),
              cost > 0 else { return }
        
        let updatedGoal = SelectedGoal(
            goalCategory: goal.goalCategory,
            goalName: goal.goalName,
            estimatedCost: cost,
            targetDate: hasTargetDate ? targetDate : nil,
            currentSavings: Double(currentSavings) ?? 0,
            importance: Int(importance),
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.updateSelectedGoal(at: viewModel.currentGoalIndex, with: updatedGoal)
    }
}

#Preview {
    GoalDetailStepView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

