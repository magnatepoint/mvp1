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
fun CategoriesTabView(viewModel: SpendSenseViewModel) {
    val kpis by viewModel.kpis.collectAsStateWithLifecycle()
    val isLoading by viewModel.isKPIsLoading.collectAsStateWithLifecycle()
    val error by viewModel.kpisError.collectAsStateWithLifecycle()

    when {
        isLoading -> {
            LoadingIndicator()
        }
        error != null -> {
            ErrorView(
                message = error.toString(),
                onRetry = { viewModel.loadKPIs() }
            )
        }
        kpis != null -> {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Placeholder - will be enhanced with charts
                Text(
                    text = "Categories View",
                    style = MaterialTheme.typography.headlineMedium
                )
                Text(
                    text = "Top Categories: ${kpis?.topCategories?.size ?: 0}",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
        else -> {
            ErrorView(
                message = "No data available",
                onRetry = { viewModel.loadKPIs() }
            )
        }
    }
}

