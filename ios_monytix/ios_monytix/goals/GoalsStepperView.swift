//
//  GoalsStepperView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalsStepperView: View {
    @ObservedObject var viewModel: GoalsViewModel
    let onComplete: () -> Void
    
    @State private var navigationPath = NavigationPath()
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(red: 0.18, green: 0.18, blue: 0.18)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Step Indicator
                    stepIndicator
                    
                    // Step Content
                    stepContent
                }
            }
            .navigationDestination(for: Int.self) { step in
                stepView(for: step)
            }
            .task {
                await loadInitialData()
            }
        }
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(1...4, id: \.self) { step in
                Circle()
                    .fill(step <= viewModel.currentStep ? goldColor : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                if step < 4 {
                    Rectangle()
                        .fill(step < viewModel.currentStep ? goldColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case 1:
            LifeContextStepView(viewModel: viewModel)
        case 2:
            GoalSelectionStepView(viewModel: viewModel)
        case 3:
            GoalDetailStepView(viewModel: viewModel)
        case 4:
            ReviewStepView(viewModel: viewModel, onComplete: onComplete)
        default:
            LifeContextStepView(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private func stepView(for step: Int) -> some View {
        switch step {
        case 1:
            LifeContextStepView(viewModel: viewModel)
        case 2:
            GoalSelectionStepView(viewModel: viewModel)
        case 3:
            GoalDetailStepView(viewModel: viewModel)
        case 4:
            ReviewStepView(viewModel: viewModel, onComplete: onComplete)
        default:
            LifeContextStepView(viewModel: viewModel)
        }
    }
    
    private func loadInitialData() async {
        await viewModel.loadCatalog()
        await viewModel.loadLifeContext()
        
        // If life context exists, load recommended goals
        if viewModel.lifeContext != nil {
            await viewModel.loadRecommendedGoals()
        }
    }
}

#Preview {
    GoalsStepperView(viewModel: GoalsViewModel(authService: AuthService())) {
        print("Completed")
    }
}

