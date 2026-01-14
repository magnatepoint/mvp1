//
//  BudgetAllocationBar.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct BudgetAllocationBar: View {
    let needsPct: Double
    let wantsPct: Double
    let savingsPct: Double
    
    private let needsColor = Color.blue
    private let wantsColor = Color.orange
    private let savingsColor = Color.green
    
    var body: some View {
        VStack(spacing: 12) {
            // Allocation Bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Needs
                    Rectangle()
                        .fill(needsColor)
                        .frame(width: geometry.size.width * needsPct)
                    
                    // Wants
                    Rectangle()
                        .fill(wantsColor)
                        .frame(width: geometry.size.width * wantsPct)
                    
                    // Savings
                    Rectangle()
                        .fill(savingsColor)
                        .frame(width: geometry.size.width * savingsPct)
                }
                .cornerRadius(8)
            }
            .frame(height: 24)
            
            // Labels
            HStack(spacing: 16) {
                Label("Needs \(Int(needsPct * 100))%", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(needsColor)
                
                Label("Wants \(Int(wantsPct * 100))%", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(wantsColor)
                
                Label("Savings \(Int(savingsPct * 100))%", systemImage: "circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(savingsColor)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BudgetAllocationBar(needsPct: 0.5, wantsPct: 0.3, savingsPct: 0.2)
        BudgetAllocationBar(needsPct: 0.6, wantsPct: 0.2, savingsPct: 0.2)
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

