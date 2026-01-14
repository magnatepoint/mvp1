//
//  AccountsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct AccountsTabView: View {
    @ObservedObject var viewModel: MolyConsoleViewModel
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isAccountsLoading {
                    ProgressView()
                        .tint(goldColor)
                        .padding(.top, 40)
                } else if let error = viewModel.accountsError {
                    errorState(error)
                } else if viewModel.accounts.isEmpty {
                    emptyState
                } else {
                    accountsContent
                }
            }
            .padding(20)
        }
        .refreshable {
            await viewModel.loadAccounts()
        }
    }
    
    private var accountsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Accounts")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(viewModel.accounts) { account in
                AccountCard(account: account)
            }
        }
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Unable to Load Accounts")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry") {
                Task {
                    await viewModel.loadAccounts()
                }
            }
            .buttonStyle(GoldButtonStyle())
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Accounts")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Link your bank accounts to see balances")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
}

// MARK: - Account Card

struct AccountCard: View {
    let account: Account
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            HStack(spacing: 16) {
                // Account Icon
                ZStack {
                    Circle()
                        .fill(colorForAccountType(account.accountType).opacity(0.2))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: account.accountType.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(colorForAccountType(account.accountType))
                }
                
                // Account Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(account.bankName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Text(account.accountType.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                        
                        if let accountNumber = account.accountNumber {
                            Text("• \(accountNumber)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Balance
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(account.balance))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private func colorForAccountType(_ type: AccountType) -> Color {
        switch type {
        case .checking:
            return .blue
        case .savings:
            return .green
        case .investment:
            return .purple
        case .credit:
            return .red
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "₹0"
    }
}

#Preview {
    let authService = AuthService()
    return AccountsTabView(viewModel: MolyConsoleViewModel(authService: authService))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

