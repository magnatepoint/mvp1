//
//  ContentView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Supabase

enum AppTab: Int, CaseIterable {
    case molyConsole = 0
    case spendSense
    case goalTracker
    case budgetPilot
    case moneyMoments
    case settings
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab: AppTab = .molyConsole

    var body: some View {
        TabView(selection: $selectedTab) {
            MolyConsoleView(isSelected: selectedTab == .molyConsole)
                .tabItem { Label("MolyConsole", systemImage: "square.grid.2x2") }
                .tag(AppTab.molyConsole)

            SpendSenseView(isSelected: selectedTab == .spendSense)
                .tabItem { Label("SpendSense", systemImage: "chart.bar.doc.horizontal") }
                .tag(AppTab.spendSense)

            GoalTrackerView(isSelected: selectedTab == .goalTracker)
                .tabItem { Label("GoalTracker", systemImage: "target") }
                .tag(AppTab.goalTracker)

            BudgetPilotView(isSelected: selectedTab == .budgetPilot)
                .tabItem { Label("BudgetPilot", systemImage: "airplane.departure") }
                .tag(AppTab.budgetPilot)

            MoneyMomentsView(isSelected: selectedTab == .moneyMoments)
                .tabItem { Label("MoneyMoments", systemImage: "sparkles") }
                .tag(AppTab.moneyMoments)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .accentColor(Color(red: 0.831, green: 0.686, blue: 0.216))
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
