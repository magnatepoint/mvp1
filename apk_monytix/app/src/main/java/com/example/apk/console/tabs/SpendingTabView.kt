package com.example.apk.console.tabs

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.apk.console.MolyConsoleViewModel
import com.example.apk.ui.components.GlassCard
import com.example.apk.ui.theme.Gold
import com.example.apk.ui.theme.TextPrimary
import com.example.apk.ui.theme.TextSecondary
import com.example.apk.console.utils.formatCurrency
import java.util.Locale

@Composable
fun SpendingTabView(viewModel: MolyConsoleViewModel) {
    val monthlySpending by viewModel.monthlySpending.collectAsStateWithLifecycle()
    val spendingByCategory by viewModel.spendingByCategory.collectAsStateWithLifecycle()
    val isLoading by viewModel.isSpendingLoading.collectAsStateWithLifecycle()
    val error by viewModel.spendingError.collectAsStateWithLifecycle()
    
    when {
        isLoading -> {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = Gold)
            }
        }
        error != null -> {
            SpendingErrorState(error = error ?: "Unknown error") {
                viewModel.loadSpending()
            }
        }
        spendingByCategory.isEmpty() -> {
            SpendingEmptyState()
        }
        else -> {
            SpendingContent(
                monthlySpending = monthlySpending,
                spendingByCategory = spendingByCategory
            )
        }
    }
}

@Composable
fun SpendingContent(
    monthlySpending: Double,
    spendingByCategory: List<com.example.apk.console.models.CategorySpending>
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // This Month's Spending
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "This Month's Spending",
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = TextSecondary
            )
            
            Text(
                text = formatCurrency(monthlySpending),
                fontSize = 32.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFFE53935)
            )
        }
        
        // Spending by Category
        Text(
            text = "Spending by Category",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth()
        )
        
        spendingByCategory.forEach { category ->
            CategorySpendingCard(
                category = category,
                totalSpending = monthlySpending
            )
        }
    }
}

@Composable
fun CategorySpendingCard(
    category: com.example.apk.console.models.CategorySpending,
    totalSpending: Double
) {
    GlassCard(
        padding = PaddingValues(16.dp),
        cornerRadius = 16.dp
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = category.category,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )
                
                Text(
                    text = formatCurrency(category.amount),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            }
            
            // Progress Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                LinearProgressIndicator(
                    progress = { (category.percentage / 100).toFloat() },
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp),
                    color = Gold,
                    trackColor = TextSecondary.copy(alpha = 0.2f)
                )
                
                Text(
                    text = "${String.format(Locale.getDefault(), "%.1f", category.percentage)}%",
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = TextSecondary,
                    modifier = Modifier.width(50.dp)
                )
            }
            
            Text(
                text = "${category.transactionCount} transactions",
                fontSize = 12.sp,
                color = TextSecondary.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun SpendingErrorState(error: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Error,
            contentDescription = null,
            tint = Color(0xFFE53935).copy(alpha = 0.7f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "Unable to Load Spending",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )
        
        Text(
            text = error,
            fontSize = 14.sp,
            color = TextSecondary,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
        
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(containerColor = Gold)
        ) {
            Text("Retry", color = com.example.apk.ui.theme.Charcoal)
        }
    }
}

@Composable
private fun SpendingEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.AttachMoney,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Spending Data",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        
        Text(
            text = "Upload statements to see your spending breakdown",
            fontSize = 14.sp,
            color = TextSecondary,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}


