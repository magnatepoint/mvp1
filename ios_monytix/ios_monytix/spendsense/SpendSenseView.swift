//
//  SpendSenseView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

enum SpendSenseTab: String, CaseIterable {
    case categories = "Categories"
    case transactions = "Transactions"
    case insights = "Insights"
}

struct SpendSenseView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel: SpendSenseViewModel
    @State private var selectedTab: SpendSenseTab = .categories
    @State private var showFilterSheet = false
    var isSelected: Bool

    init(isSelected: Bool = true) {
        self.isSelected = isSelected
        let authService = AuthService()
        _viewModel = StateObject(wrappedValue: SpendSenseViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.charcoal.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Tab Bar
                    customTabBar
                    
                    // Filter Bar (Only for Transactions)
                    if selectedTab == .transactions {
                        filterBar
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Theme.charcoal)
                    }
                    
                    // Tab Content
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("SpendSense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.charcoal, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await refreshCurrentTab()
                            }
                        }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            Task {
                                try? await authManager.signOut()
                            }
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.gold)
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(viewModel: viewModel)
            }
        }
        .task(id: isSelected) {
            guard isSelected else { return }
            await loadInitialData()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search transactions...", text: $viewModel.searchText)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Theme.darkGray)
            .cornerRadius(8)
            
            // Filter Button
            Button(action: { showFilterSheet = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22))
                    .foregroundColor(hasActiveFilters ? Theme.gold : .gray)
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        viewModel.selectedCategoryCode != nil || viewModel.selectedStartDate != nil || viewModel.selectedEndDate != nil
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(SpendSenseTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? Theme.gold : .gray.opacity(0.7))
                        
                        // Indicator
                        Rectangle()
                            .fill(Theme.gold)
                            .frame(height: 3)
                            .cornerRadius(1.5)
                            .opacity(selectedTab == tab ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Theme.charcoal)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .categories:
            KPIsTabView(viewModel: viewModel, userEmail: authManager.userEmail)
        case .transactions:
            TransactionsTabView(viewModel: viewModel)
        case .insights:
            InsightsTabView(viewModel: viewModel)
        }
    }
    
    private func loadInitialData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await viewModel.loadAvailableMonths() }
            group.addTask { await viewModel.loadKPIs() }
            group.addTask { await viewModel.loadTransactions() }
        }
    }
    
    private func refreshCurrentTab() async {
        switch selectedTab {
        case .categories: await viewModel.loadKPIs()
        case .transactions: await viewModel.reloadTransactions() // Reloads with current filters
        case .insights: await viewModel.loadInsights()
        }
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @ObservedObject var viewModel: SpendSenseViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.charcoal.ignoresSafeArea()
                
                Form {
                    Section(header: Text("Date Range").foregroundColor(Theme.gold)) {
                        DatePicker("Start Date", selection: Binding(
                            get: { viewModel.selectedStartDate ?? Date() },
                            set: { viewModel.selectedStartDate = $0 }
                        ), displayedComponents: .date)
                        
                        DatePicker("End Date", selection: Binding(
                            get: { viewModel.selectedEndDate ?? Date() },
                            set: { viewModel.selectedEndDate = $0 }
                        ), displayedComponents: .date)
                        
                        Button("Clear Dates") {
                            viewModel.selectedStartDate = nil
                            viewModel.selectedEndDate = nil
                        }
                        .foregroundColor(.red)
                    }
                    .listRowBackground(Theme.darkGray)
                    
                    Section(header: Text("Category").foregroundColor(Theme.gold)) {
                        // Ideally fetching categories from service, simplified here
                         TextField("Category Code (e.g. food)", text: Binding(
                             get: { viewModel.selectedCategoryCode ?? "" },
                             set: { viewModel.selectedCategoryCode = $0.isEmpty ? nil : $0 }
                         ))
                    }
                    .listRowBackground(Theme.darkGray)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await viewModel.reloadTransactions()
                            dismiss()
                        }
                    }
                    .foregroundColor(Theme.gold)
                }
            }
        }
    }
}

#Preview {
    SpendSenseView(isSelected: true)
        .environmentObject(AuthManager())
}

