package com.example.apk.console.tabs

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.example.apk.console.utils.formatCurrency
import com.example.apk.console.utils.formatNumber
import java.util.Locale

@Composable
fun GoalsTabView(viewModel: MolyConsoleViewModel) {
    val goals by viewModel.goals.collectAsStateWithLifecycle()
    val isLoading by viewModel.isGoalsLoading.collectAsStateWithLifecycle()
    val error by viewModel.goalsError.collectAsStateWithLifecycle()
    
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
            GoalsErrorState(error = errorMsg ?: "Unknown error") {
                viewModel.loadGoals()
            }
        }
        goals.isEmpty() -> {
            GoalsEmptyState()
        }
        else -> {
            val activeGoals = goals.filter { goal -> goal.isActive }
        GoalsContent(goals = activeGoals)
        }
    }
}

@Composable
fun GoalsContent(goals: List<com.example.apk.console.models.Goal>) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Financial Goals",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth()
        )
        
        goals.forEach { goal ->
            GoalCard(goal = goal)
        }
    }
}

@Composable
fun GoalCard(goal: com.example.apk.console.models.Goal) {
    GlassCard(
        padding = PaddingValues(20.dp),
        cornerRadius = 16.dp
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Flag,
                    contentDescription = null,
                    tint = Color(0xFF9C27B0),
                    modifier = Modifier.size(20.dp)
                )
                
                Text(
                    text = goal.name,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            }
            
            // Amounts
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "Saved",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextSecondary
                    )
                    
                    Text(
                        text = formatCurrency(goal.savedAmount),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                }
                
                Column(
                    horizontalAlignment = Alignment.End,
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "Target",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextSecondary
                    )
                    
                    Text(
                        text = formatCurrency(goal.targetAmount),
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                }
            }
            
            // Progress
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "${String.format(Locale.getDefault(), "%.1f", goal.progressPercentage)}% Complete",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Gold
                )
                
                LinearProgressIndicator(
                    progress = { goal.progress.toFloat() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(12.dp),
                    color = Gold,
                    trackColor = TextSecondary.copy(alpha = 0.2f)
                )
                
                Text(
                    text = "₹${formatNumber(goal.remainingAmount)} remaining",
                    fontSize = 12.sp,
                    color = TextSecondary.copy(alpha = 0.6f)
                )
            }
        }
    }
}

@Composable
private fun GoalsErrorState(error: String, onRetry: () -> Unit) {
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
            text = "Unable to Load Goals",
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
private fun GoalsEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.TrackChanges,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Goals",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        
        Text(
            text = "Create financial goals to track your progress",
            fontSize = 14.sp,
            color = TextSecondary,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}


