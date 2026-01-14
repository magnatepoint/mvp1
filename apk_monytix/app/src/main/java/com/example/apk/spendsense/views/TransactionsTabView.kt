package com.example.apk.spendsense.views

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.apk.spendsense.SpendSenseViewModel
import com.example.apk.ui.components.ErrorView
import com.example.apk.ui.components.LoadingIndicator
import com.example.apk.ui.theme.Gold

@Composable
fun TransactionsTabView(viewModel: SpendSenseViewModel) {
    val transactions by viewModel.transactions.collectAsStateWithLifecycle()
    val isLoading by viewModel.isTransactionsLoading.collectAsStateWithLifecycle()
    val error by viewModel.transactionsError.collectAsStateWithLifecycle()
    var showUploadModal by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize()) {
        when {
            isLoading -> {
                LoadingIndicator()
            }
            error != null -> {
                ErrorView(
                    message = error ?: "Unknown error",
                    onRetry = { viewModel.loadTransactions() }
                )
            }
            transactions.isEmpty() -> {
                ErrorView(
                    message = "No transactions found",
                    onRetry = { viewModel.loadTransactions() }
                )
            }
            else -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(transactions) { transaction ->
                        TransactionRow(transaction = transaction)
                    }
                }
            }
        }

        // Floating Action Button
        FloatingActionButton(
            onClick = { showUploadModal = true },
            modifier = Modifier
                .align(androidx.compose.ui.Alignment.BottomEnd)
                .padding(16.dp),
            containerColor = Gold
        ) {
            Icon(Icons.Default.Add, contentDescription = "Upload")
        }
    }

    // Upload Modal - placeholder
    if (showUploadModal) {
        // TODO: Implement file upload modal
    }
}

@Composable
fun TransactionRow(transaction: com.example.apk.spendsense.models.Transaction) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = androidx.compose.ui.graphics.Color(0xFF262626)
        )
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = transaction.merchant ?: transaction.description ?: "Transaction",
                style = MaterialTheme.typography.titleMedium
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${transaction.amount} ${transaction.direction}",
                style = MaterialTheme.typography.bodyMedium
            )
            Text(
                text = transaction.txnDate,
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}


