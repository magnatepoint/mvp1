package com.example.apk.console.tabs

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
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
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.Gold
import com.example.apk.ui.theme.TextPrimary
import com.example.apk.ui.theme.TextSecondary
import com.example.apk.console.utils.formatCurrency
import java.text.NumberFormat
import java.util.Locale

@Composable
fun OverviewTabView(viewModel: MolyConsoleViewModel) {
    val overviewSummary by viewModel.overviewSummary.collectAsStateWithLifecycle()
    val isLoading by viewModel.isOverviewLoading.collectAsStateWithLifecycle()
    val error by viewModel.overviewError.collectAsStateWithLifecycle()
    
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
            val errorMsg = error
            OverviewErrorState(error = errorMsg ?: "Unknown error") {
                viewModel.loadOverview()
            }
        }
        overviewSummary != null -> {
            val summary = overviewSummary
            if (summary != null) {
                OverviewContent(summary = summary)
            } else {
                OverviewEmptyState()
            }
        }
        else -> {
            OverviewEmptyState()
        }
    }
}

@Composable
fun OverviewContent(summary: com.example.apk.console.models.OverviewSummary) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Quick Overview",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth()
        )
        
        // Summary Cards Grid
        LazyVerticalGrid(
            columns = GridCells.Fixed(2),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.height(200.dp)
        ) {
            items(listOf(
                SummaryCardData(
                    title = "Total Balance",
                    value = formatCurrency(summary.totalBalance),
                    color = Color(0xFF4CAF50),
                    icon = Icons.Default.AccountBalance
                ),
                SummaryCardData(
                    title = "This Month",
                    value = formatCurrency(summary.thisMonthSpending),
                    color = Color(0xFFE53935),
                    icon = Icons.Default.CalendarToday
                ),
                SummaryCardData(
                    title = "Savings Rate",
                    value = "${String.format(Locale.getDefault(), "%.1f", summary.savingsRate)}%",
                    color = Color(0xFF4CAF50),
                    icon = Icons.Default.TrendingUp
                ),
                SummaryCardData(
                    title = "Active Goals",
                    value = "${summary.activeGoalsCount}",
                    color = Gold,
                    icon = Icons.Default.TrackChanges
                )
            )) { data ->
                SummaryCard(data = data)
            }
        }
        
        // AI Insight Card
        summary.latestInsight?.let { insight ->
            AIInsightCard(insight = insight)
        }
    }
}

data class SummaryCardData(
    val title: String,
    val value: String,
    val color: Color,
    val icon: androidx.compose.ui.graphics.vector.ImageVector
)

@Composable
fun SummaryCard(data: SummaryCardData) {
    GlassCard(
        padding = PaddingValues(16.dp),
        cornerRadius = 16.dp
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row {
                Icon(
                    imageVector = data.icon,
                    contentDescription = null,
                    tint = data.color,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.weight(1f))
            }
            
            Text(
                text = data.title,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = TextSecondary
            )
            
            Text(
                text = data.value,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
        }
    }
}

@Composable
fun AIInsightCard(insight: com.example.apk.console.models.AIInsight) {
    GlassCard(
        padding = PaddingValues(20.dp),
        cornerRadius = 16.dp
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = getInsightIcon(insight.type),
                    contentDescription = null,
                    tint = getInsightColor(insight.type),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "AI Insight",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextSecondary
                )
            }
            
            Text(
                text = insight.message,
                fontSize = 15.sp,
                color = TextPrimary,
                maxLines = 3
            )
        }
    }
}

@Composable
private fun OverviewErrorState(error: String, onRetry: () -> Unit) {
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
            text = "Unable to Load Overview",
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
            Text("Retry", color = Charcoal)
        }
    }
}

@Composable
private fun OverviewEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.BarChart,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Overview Data",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        
        Text(
            text = "Upload statements to see your financial overview",
            fontSize = 14.sp,
            color = TextSecondary,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}


private fun getInsightIcon(type: com.example.apk.console.models.InsightType): androidx.compose.ui.graphics.vector.ImageVector {
    return when (type) {
        com.example.apk.console.models.InsightType.SPENDING_ALERT -> Icons.Default.Warning
        com.example.apk.console.models.InsightType.GOAL_PROGRESS -> Icons.Default.CheckCircle
        com.example.apk.console.models.InsightType.INVESTMENT_RECOMMENDATION -> Icons.Default.TrendingUp
        com.example.apk.console.models.InsightType.BUDGET_TIP -> Icons.Default.Lightbulb
        com.example.apk.console.models.InsightType.SAVINGS_OPPORTUNITY -> Icons.Default.AccountBalance
    }
}

private fun getInsightColor(type: com.example.apk.console.models.InsightType): Color {
    return when (type) {
        com.example.apk.console.models.InsightType.SPENDING_ALERT -> Color(0xFFFFEB3B)
        com.example.apk.console.models.InsightType.GOAL_PROGRESS -> Color(0xFF4CAF50)
        com.example.apk.console.models.InsightType.INVESTMENT_RECOMMENDATION -> Color(0xFF9C27B0)
        com.example.apk.console.models.InsightType.BUDGET_TIP -> Color(0xFF2196F3)
        com.example.apk.console.models.InsightType.SAVINGS_OPPORTUNITY -> Color(0xFF4CAF50)
    }
}

