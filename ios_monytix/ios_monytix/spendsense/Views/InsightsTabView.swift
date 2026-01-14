//
//  InsightsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct InsightsTabView: View {
    @ObservedObject var viewModel: SpendSenseViewModel
    @State private var categoryLimit: CategoryLimit = .all
    @State private var selectedCategoryForSubcategories: CategoryBreakdown?
    @State private var subcategories: [SubcategoryBreakdown] = []
    @State private var selectedCategory: CategoryBreakdown?
    @State private var showCategoryDetail = false
    
    enum CategoryLimit: String, CaseIterable {
        case all = "All"
        case top5 = "Top 5"
        case top10 = "Top 10"
        
        var limit: Int? {
            switch self {
            case .all: return nil
            case .top5: return 5
            case .top10: return 10
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isInsightsLoading {
                    ProgressView()
                        .tint(Color(red: 0.831, green: 0.686, blue: 0.216))
                        .padding(.top, 40)
                } else if let error = viewModel.insightsError {
                    errorState(error)
                } else if let insights = viewModel.insights {
                    insightsContent(insights)
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadInsights()
        }
        .onAppear {
            if viewModel.insights == nil {
                Task {
                    await viewModel.loadInsights()
                }
            }
        }
        .sheet(isPresented: $showCategoryDetail) {
            if let category = selectedCategory {
                CategoryDetailView(category: category, isPresented: $showCategoryDetail)
            }
        }
    }
    
    private func insightsContent(_ insights: Insights) -> some View {
        VStack(spacing: 24) {
            // Insights Summary
            InsightsSummaryCard(insights: insights)
            
            // Category Breakdown
            if let breakdown = insights.categoryBreakdown, !breakdown.isEmpty {
                categoryBreakdownView(breakdown)
            }
            
            // Recurring Transactions
            if let recurring = insights.recurringTransactions, !recurring.isEmpty {
                recurringTransactionsView(recurring)
            }
        }
    }
    
    private func categoryBreakdownView(_ breakdown: [CategoryBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Category Limit Selector
            HStack {
                Text("Category Breakdown")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Category Limit Selector
                Menu {
                    ForEach(CategoryLimit.allCases, id: \.self) { limit in
                        Button(action: {
                            categoryLimit = limit
                        }) {
                            HStack {
                                Text(limit.rawValue)
                                if categoryLimit == limit {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number")
                            .font(.system(size: 12))
                        Text(categoryLimit.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.831, green: 0.686, blue: 0.216))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.831, green: 0.686, blue: 0.216).opacity(0.2))
                    )
                }
            }
            .padding(.horizontal, 4)
            
            // Interactive Donut Chart
            let sortedCategories = breakdown.sorted(by: { $0.amount > $1.amount })
            let limitedCategories = applyCategoryLimit(sortedCategories)
            
            CategoryDonutChart(
                categories: limitedCategories,
                subcategories: selectedCategoryForSubcategories != nil ? subcategories : nil,
                onCategorySelected: { category in
                    selectedCategory = category
                    showCategoryDetail = true
                },
                onCategoryTapped: { category in
                    selectedCategoryForSubcategories = category
                    if let category = category {
                        loadSubcategories(for: category)
                    } else {
                        subcategories = []
                    }
                }
            )
        }
    }
    
    private func applyCategoryLimit(_ categories: [CategoryBreakdown]) -> [CategoryBreakdown] {
        guard let limit = categoryLimit.limit else {
            return categories
        }
        
        if categories.count <= limit {
            return categories
        }
        
        // Show top N categories and aggregate the rest as "Others"
        let topCategories = Array(categories.prefix(limit))
        let others = Array(categories.suffix(from: limit))
        let othersTotal = others.reduce(0) { $0 + $1.amount }
        let othersPercentage = others.reduce(0) { $0 + $1.percentage }
        let othersCount = others.reduce(0) { $0 + $1.transactionCount }
        
        if othersTotal > 0 {
            var result = topCategories
            result.append(
                CategoryBreakdown(
                    categoryName: "Others",
                    amount: othersTotal,
                    percentage: othersPercentage,
                    transactionCount: othersCount
                )
            )
            return result
        }
        
        return topCategories
    }
    
    private func loadSubcategories(for category: CategoryBreakdown) {
        // Get subcategory breakdown from transactions
        subcategories = viewModel.getSubcategoryBreakdown(for: category.categoryName)
        
        // If no subcategories found and transactions are empty, try loading more transactions
        if subcategories.isEmpty && viewModel.transactions.isEmpty && !viewModel.isTransactionsLoading {
            Task {
                // Load a larger batch of transactions to get subcategory data (first 100)
                await viewModel.loadTransactions(limit: 100, offset: 0)
                // Reload subcategories after transactions are loaded
                subcategories = viewModel.getSubcategoryBreakdown(for: category.categoryName)
            }
        } else if subcategories.isEmpty && viewModel.transactions.count < 100 && !viewModel.isTransactionsLoading {
            // If we have some transactions but not enough, load more
            Task {
                await viewModel.loadTransactions(limit: 100, offset: viewModel.transactions.count)
                subcategories = viewModel.getSubcategoryBreakdown(for: category.categoryName)
            }
        }
    }
    
    private func recurringTransactionsView(_ recurring: [RecurringTransaction]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recurring Transactions")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                ForEach(Array(recurring.enumerated()), id: \.element.id) { index, item in
                    RecurringTransactionCard(
                        transaction: item,
                        index: index,
                        onTap: {
                            // Could navigate to transaction list filtered by merchant
                        }
                    )
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No insights available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Pull down to load insights")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(.top, 60)
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to Load Insights")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                Task {
                    await viewModel.loadInsights()
                }
            }) {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 120, height: 44)
                    .background(Color(red: 0.831, green: 0.686, blue: 0.216))
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

