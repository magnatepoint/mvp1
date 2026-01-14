package com.example.apk.console.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.apk.console.MolyConsoleViewModel
import com.example.apk.ui.components.GlassCard
import com.example.apk.ui.theme.Gold
import com.example.apk.ui.theme.TextPrimary
import com.example.apk.ui.theme.TextSecondary

@Composable
fun AIInsightTabView(viewModel: MolyConsoleViewModel) {
    val insights by viewModel.aiInsights.collectAsStateWithLifecycle()
    val isLoading by viewModel.isInsightsLoading.collectAsStateWithLifecycle()
    val error by viewModel.insightsError.collectAsStateWithLifecycle()
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // AI Banner
        AIBanner()
        
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
                InsightsErrorState(error = errorMsg ?: "Unknown error") {
                    viewModel.loadAIInsights()
                }
            }
            insights.isEmpty() -> {
                InsightsEmptyState()
            }
            else -> {
                InsightsContent(insights = insights)
            }
        }
    }
}

@Composable
fun AIBanner() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(
                Brush.horizontalGradient(
                    colors = listOf(
                        Color(0xFF8B5CF6),
                        Color(0xFF8B5CF6).copy(alpha = 0.8f)
                    )
                )
            )
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.AutoAwesome,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(20.dp)
        )
        
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = "Molytix AI",
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            
            Text(
                text = "Personalized insights and recommendations based on your financial behavior.",
                fontSize = 12.sp,
                color = Color.White.copy(alpha = 0.9f),
                maxLines = 2
            )
        }
    }
}

@Composable
fun InsightsContent(insights: List<com.example.apk.console.models.AIInsight>) {
    Column(
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Today's Insights",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth()
        )
        
        insights.forEach { insight ->
            InsightCard(insight = insight)
        }
    }
}

@Composable
fun InsightCard(insight: com.example.apk.console.models.AIInsight) {
    GlassCard(
        padding = PaddingValues(20.dp),
        cornerRadius = 16.dp
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = getInsightIcon(insight.type),
                    contentDescription = null,
                    tint = getInsightColor(insight.type),
                    modifier = Modifier.size(20.dp)
                )
                
                Text(
                    text = insight.title,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            }
            
            Text(
                text = insight.message,
                fontSize = 15.sp,
                color = TextPrimary.copy(alpha = 0.9f)
            )
        }
    }
}

@Composable
private fun InsightsErrorState(error: String, onRetry: () -> Unit) {
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
            text = "Unable to Load Insights",
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
private fun InsightsEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.AutoAwesome,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Insights Yet",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        
        Text(
            text = "AI insights will appear here as you use the app",
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

