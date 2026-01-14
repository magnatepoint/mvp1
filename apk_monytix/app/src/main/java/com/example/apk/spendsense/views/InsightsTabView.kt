package com.example.apk.spendsense.views

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.apk.spendsense.SpendSenseViewModel
import com.example.apk.ui.components.ErrorView
import com.example.apk.ui.components.LoadingIndicator

@Composable
fun InsightsTabView(viewModel: SpendSenseViewModel) {
    val insights by viewModel.insights.collectAsStateWithLifecycle()
    val isLoading by viewModel.isInsightsLoading.collectAsStateWithLifecycle()
    val error by viewModel.insightsError.collectAsStateWithLifecycle()

    when {
        isLoading -> {
            LoadingIndicator()
        }
        error != null -> {
            ErrorView(
                message = error.toString(),
                onRetry = { viewModel.loadInsights() }
            )
        }
        insights != null -> {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Insights View",
                    style = MaterialTheme.typography.headlineMedium
                )
                Text(
                    text = "Category Breakdown: ${insights?.categoryBreakdown?.size ?: 0}",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
        else -> {
            ErrorView(
                message = "No insights available",
                onRetry = { viewModel.loadInsights() }
            )
        }
    }
}

