//
//  ContentView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI
import Supabase

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            MolyConsoleView()
                .tabItem {
                    Label("MolyConsole", systemImage: "square.grid.2x2")
                }
            SpendSenseView()
                .tabItem {
                    Label("SpendSense", systemImage: "chart.bar.doc.horizontal")
                }
            
           
            
            GoalTrackerView()
                .tabItem {
                    Label("GoalTracker", systemImage: "target")
                }
            
            BudgetPilotView()
                .tabItem {
                    Label("BudgetPilot", systemImage: "airplane.departure")
                }
            
            MoneyMomentsView()
                .tabItem {
                    Label("MoneyMoments", systemImage: "sparkles")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .accentColor(Color(red: 0.831, green: 0.686, blue: 0.216))
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}
