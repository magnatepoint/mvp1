//
//  KPIsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct KPIsTabView: View {
    @ObservedObject var viewModel: SpendSenseViewModel
    var userEmail: String?
    @State private var selectedMonth: String?
    @State private var selectedKPI: String?
    @State private var showKPIDetail = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Welcome Banner
                WelcomeBanner(username: userEmail)
                
                // Month filter
                if !viewModel.availableMonths.isEmpty {
                    monthFilter
                }
                
                if viewModel.isKPILoading {
                    ProgressView()
                        .tint(Color(red: 0.831, green: 0.686, blue: 0.216))
                        .padding(.top, 40)
                } else if let error = viewModel.kpiError {
                    errorState(error)
                } else if let kpis = viewModel.kpis {
                    kpiContent(kpis)
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadKPIs(month: selectedMonth)
        }
        .sheet(isPresented: $showKPIDetail) {
            if let kpiType = selectedKPI, let kpis = viewModel.kpis {
                KPIDetailView(
                    kpiType: kpiType,
                    kpis: kpis,
                    isPresented: $showKPIDetail
                )
            }
        }
    }
    
    private var monthFilter: some View {
        GlassCard(padding: 16, cornerRadius: 16) {
            HStack {
                Text("Month:")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Picker("Month", selection: $selectedMonth) {
                    Text("Latest Available").tag(nil as String?)
                    ForEach(viewModel.availableMonths, id: \.self) { month in
                        Text(formatMonth(month)).tag(month as String?)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(red: 0.831, green: 0.686, blue: 0.216))
                .onChange(of: selectedMonth) { oldValue, newValue in
                    Task {
                        await viewModel.loadKPIs(month: newValue)
                    }
                }
            }
        }
    }
    
    private func kpiContent(_ kpis: SpendSenseKPIs) -> some View {
        VStack(spacing: 24) {
            // Financial Health Summary
            FinancialHealthCard(kpis: kpis)
            
            // Primary KPIs Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Key Metrics")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                
                // Income - Full width
                KPICard(
                    label: "Income",
                    value: kpis.incomeAmount ?? 0,
                    icon: "arrow.up.circle.fill",
                    color: Color(red: 0.298, green: 0.686, blue: 0.314),
                    index: 0,
                    trendChange: nil,
                    onTap: {
                        selectedKPI = "income"
                        showKPIDetail = true
                    }
                )
                
                // Expenses Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expenses")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                    
                    HStack(spacing: 16) {
                        KPICard(
                            label: "Needs",
                            value: kpis.needsAmount ?? 0,
                            icon: "shield.fill",
                            color: Color(red: 1.0, green: 0.596, blue: 0.0),
                            index: 1,
                            trendChange: nil,
                            onTap: {
                                selectedKPI = "needs"
                                showKPIDetail = true
                            }
                        )
                        
                        KPICard(
                            label: "Wants",
                            value: kpis.wantsAmount ?? 0,
                            icon: "shopping.bag.fill",
                            color: Color(red: 0.612, green: 0.153, blue: 0.690),
                            index: 2,
                            trendChange: nil,
                            onTap: {
                                selectedKPI = "wants"
                                showKPIDetail = true
                            }
                        )
                    }
                }
                
                // Assets - Full width
                KPICard(
                    label: "Assets",
                    value: kpis.assetsAmount ?? 0,
                    icon: "savings.fill",
                    color: Color(red: 0.129, green: 0.588, blue: 0.953),
                    index: 3,
                    trendChange: nil,
                    onTap: {
                        selectedKPI = "assets"
                        showKPIDetail = true
                    }
                )
            }
            
            // Visualizations Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Visualizations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                
                // Pie Chart
                if let needs = kpis.needsAmount,
                   let wants = kpis.wantsAmount,
                   let assets = kpis.assetsAmount,
                   needs > 0 || wants > 0 || assets > 0 {
                    ExpensePieChart(
                        data: [
                            ChartData(label: "Needs", value: needs, color: .green),
                            ChartData(label: "Wants", value: wants, color: .orange),
                            ChartData(label: "Savings", value: assets, color: .blue)
                        ],
                        size: 180,
                        title: "Expense Breakdown",
                        subtitle: "Spending by category"
                    )
                }
                
                // Wants Gauge
                if let gauge = kpis.wantsGauge {
                    WantsGaugeView(gauge: gauge)
                }
            }
            
            // Top Categories
            if let categories = kpis.topCategories, !categories.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Categories")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                    
                    topCategoriesView(categories)
                }
            }
        }
    }
    
    private func topCategoriesView(_ categories: [TopCategory]) -> some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Top Categories")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.categoryName ?? category.categoryCode ?? "Unknown")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                if let share = category.share {
                                    Text("\(String(format: "%.1f", share * 100))% share • \(category.txnCount ?? 0) txns")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray.opacity(0.7))
                                } else {
                                    Text("\(category.txnCount ?? 0) transactions")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(formatCurrency(category.spendAmount ?? 0))
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                
                                if let changePct = category.changePct {
                                    Text("\(changePct >= 0 ? "+" : "")\(String(format: "%.1f", changePct))%")
                                        .font(.system(size: 12))
                                        .foregroundColor(changePct >= 0 ? .red : .green)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if index < categories.count - 1 {
                        Divider()
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No KPI data available")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Upload transaction statements to see your spending insights")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to Load Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                Task {
                    await viewModel.loadKPIs(month: selectedMonth)
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
    
    private func formatMonth(_ monthString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        
        if let date = formatter.date(from: monthString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM yyyy"
            return displayFormatter.string(from: date)
        }
        
        return monthString
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

