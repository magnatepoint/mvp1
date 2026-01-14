//
//  GoalProgressView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GoalProgressView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isProgressLoading {
                    ProgressView()
                        .tint(Color(red: 0.831, green: 0.686, blue: 0.216))
                        .padding(.top, 40)
                } else if viewModel.progress.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.progress) { goalProgress in
                        GoalProgressCard(goalProgress: goalProgress)
                    }
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadProgress()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Progress Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Goal progress will appear here once tracking begins")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

#Preview {
    GoalProgressView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

