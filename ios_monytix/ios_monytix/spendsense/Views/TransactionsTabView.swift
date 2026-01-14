//
//  TransactionsTabView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct TransactionsTabView: View {
    @ObservedObject var viewModel: SpendSenseViewModel
    @State private var selectedTransaction: Transaction?
    @State private var showTransactionDetail = false
    @State private var showUploadModal = false
    
    var body: some View {
        ZStack {
            Theme.charcoal.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Transactions list
                        if viewModel.isTransactionsLoading {
                            ProgressView()
                                .tint(Theme.gold)
                                .padding(.top, 40)
                        } else if let error = viewModel.transactionsError {
                            errorState(error)
                        } else if viewModel.transactions.isEmpty {
                            emptyState
                        } else {
                            transactionsList
                        }
                        
                        // Load More Button
                        if viewModel.totalCount > viewModel.transactions.count {
                            loadMoreButton
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 80) // Space for FAB
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingUploadButton {
                        showUploadModal = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .refreshable {
            await viewModel.loadTransactions()
        }
        .sheet(isPresented: $showTransactionDetail) {
            if let transaction = selectedTransaction {
                TransactionDetailView(transaction: transaction, isPresented: $showTransactionDetail)
            }
        }
        .sheet(isPresented: $showUploadModal) {
            FileUploadCard(
                pdfPassword: $viewModel.pdfPassword,
                isUploading: $viewModel.isUploading,
                uploadProgress: $viewModel.uploadProgress,
                uploadError: $viewModel.uploadError,
                isPresented: $showUploadModal,
                onFileSelected: { url in
                    Task {
                        await viewModel.uploadFile(fileURL: url)
                    }
                },
                onUploadComplete: {
                    // Reload transactions after successful upload
                    Task {
                        await viewModel.loadTransactions()
                    }
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    // Note: Filtering is now handled by the backend via ViewModel.
    
    private var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: viewModel.transactions) { transaction in
            formatDateGroup(transaction.txnDate)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    

    
    private func formatDateGroup(_ dateString: String) -> String {
        guard let date = parseDate(dateString) else { return "Other" }
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "This Week"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return "This Month"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
    
    private var transactionsList: some View {
        VStack(spacing: 24) {
            ForEach(groupedTransactions, id: \.0) { group in
                VStack(alignment: .leading, spacing: 12) {
                    // Section Header
                    Text(group.0)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                    
                    // Transactions in group
                    GlassCard(padding: 0, cornerRadius: 16) {
                        VStack(spacing: 0) {
                            ForEach(Array(group.1.enumerated()), id: \.element.id) { index, transaction in
                                TransactionRow(transaction: transaction) {
                                    selectedTransaction = transaction
                                    showTransactionDetail = true
                                }
                                
                                if index < group.1.count - 1 {
                                    Divider()
                                        .background(Color.gray.opacity(0.2))
                                        .padding(.leading, 80)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var loadMoreButton: some View {
        Button(action: {
            viewModel.nextPage()
            Task {
                await viewModel.loadTransactions()
            }
        }) {
            HStack {
                Text("Load More")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.831, green: 0.686, blue: 0.216))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private var paginationView: some View {
        let totalPages = max(1, (viewModel.totalCount + 24) / 25)
        
        return GlassCard(padding: 16, cornerRadius: 16) {
            HStack {
                Button(action: {
                    viewModel.previousPage()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(viewModel.currentPage > 1 ? .white : .gray)
                }
                .disabled(viewModel.currentPage <= 1)
                
                Spacer()
                
                Text("Page \(viewModel.currentPage) of \(totalPages)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    viewModel.nextPage()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(viewModel.currentPage < totalPages ? .white : .gray)
                }
                .disabled(viewModel.currentPage >= totalPages)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No transactions found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 8) {
                Text("Tap the upload button to import transactions")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 12))
                    Text("Bottom right corner")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(red: 0.831, green: 0.686, blue: 0.216))
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }
    
    private func errorState(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to Load Transactions")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: {
                Task {
                    await viewModel.loadTransactions()
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
}

