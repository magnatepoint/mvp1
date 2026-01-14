package com.example.apk.budget

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.auth.AuthService
import com.example.apk.auth.AuthViewModel
import com.example.apk.ui.components.GlassCard
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.Gold
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BudgetPilotScreen(
    authViewModel: AuthViewModel
) {
    val authService = remember { AuthService(null) }
    val viewModel: BudgetViewModel = viewModel(
        factory = BudgetViewModelFactory(authService)
    )

    val recommendations by viewModel.recommendations.collectAsState()
    val isRecommendationsLoading by viewModel.isRecommendationsLoading.collectAsState()
    val recommendationsError by viewModel.recommendationsError.collectAsState()
    val committedBudget by viewModel.committedBudget.collectAsState()
    val isCommittedLoading by viewModel.isCommittedLoading.collectAsState()
    val isCommitting by viewModel.isCommitting.collectAsState()

    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        viewModel.loadRecommendations()
        viewModel.loadCommittedBudget()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("BudgetPilot") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Charcoal,
                    titleContentColor = Color.White
                ),
                actions = {
                    IconButton(onClick = {
                        scope.launch {
                            viewModel.loadRecommendations()
                            viewModel.loadCommittedBudget()
                        }
                    }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            tint = Gold
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(Charcoal)
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            // Header
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "BudgetPilot",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    text = "Smart budget recommendations tailored to your spending patterns and goals",
                    fontSize = 16.sp,
                    color = Color.Gray.copy(alpha = 0.7f)
                )
            }

            // Committed Budget Section
            if (isCommittedLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 20.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Gold)
                }
            } else if (committedBudget != null) {
                CommittedBudgetSection(committedBudget = committedBudget!!)
            }

            // Recommendations Section
            Text(
                text = if (committedBudget != null) "Other Recommendations" else "Recommended Budget Plans",
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            when {
                isRecommendationsLoading -> {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 40.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Gold)
                    }
                }
                recommendationsError != null -> {
                    ErrorState(
                        error = recommendationsError!!,
                        onRetry = { scope.launch { viewModel.loadRecommendations() } }
                    )
                }
                recommendations.isEmpty() -> {
                    EmptyBudgetState()
                }
                else -> {
                    recommendations.forEach { recommendation ->
                        BudgetRecommendationCard(
                            recommendation = recommendation,
                            isCommitted = committedBudget?.planCode == recommendation.planCode,
                            isCommitting = isCommitting,
                            onCommit = {
                                viewModel.commitToPlan(recommendation.planCode)
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun CommittedBudgetSection(committedBudget: CommittedBudget) {
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Your Committed Budget",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        GlassCard {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = committedBudget.planCode.replace("_", " ").uppercase(),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    
                    Surface(
                        color = Gold.copy(alpha = 0.2f),
                        shape = MaterialTheme.shapes.small
                    ) {
                        Text(
                            text = "COMMITTED",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = Gold
                        )
                    }
                }

                HorizontalDivider(color = Color.Gray.copy(alpha = 0.3f))

                // Budget Breakdown
                BudgetBar(
                    needsPct = committedBudget.allocNeedsPct,
                    wantsPct = committedBudget.allocWantsPct,
                    savingsPct = committedBudget.allocAssetsPct
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    BudgetItem("Needs", committedBudget.allocNeedsPct, Color(0xFF4CAF50))
                    BudgetItem("Wants", committedBudget.allocWantsPct, Color(0xFF2196F3))
                    BudgetItem("Savings", committedBudget.allocAssetsPct, Gold)
                }
            }
        }
    }
}

@Composable
fun BudgetRecommendationCard(
    recommendation: BudgetRecommendation,
    isCommitted: Boolean,
    isCommitting: Boolean,
    onCommit: () -> Unit
) {
    GlassCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = recommendation.name,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    
                    recommendation.description?.let { desc ->
                        Text(
                            text = desc,
                            fontSize = 14.sp,
                            color = Color.Gray,
                            modifier = Modifier.padding(top = 4.dp)
                        )
                    }
                }

                Surface(
                    color = Gold.copy(alpha = 0.2f),
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        text = "${String.format("%.0f", recommendation.score * 100)}%",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = Gold
                    )
                }
            }

            HorizontalDivider(color = Color.Gray.copy(alpha = 0.3f))

            // Budget Breakdown
            BudgetBar(
                needsPct = recommendation.needsBudgetPct,
                wantsPct = recommendation.wantsBudgetPct,
                savingsPct = recommendation.savingsBudgetPct
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                BudgetItem("Needs", recommendation.needsBudgetPct, Color(0xFF4CAF50))
                BudgetItem("Wants", recommendation.wantsBudgetPct, Color(0xFF2196F3))
                BudgetItem("Savings", recommendation.savingsBudgetPct, Gold)
            }

            // Recommendation Reason
            Text(
                text = recommendation.recommendationReason,
                fontSize = 14.sp,
                color = Color.Gray,
                lineHeight = 20.sp
            )

            // Commit Button
            if (!isCommitted) {
                Button(
                    onClick = onCommit,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isCommitting,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Gold,
                        contentColor = Color.Black
                    )
                ) {
                    if (isCommitting) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = Color.Black,
                            strokeWidth = 2.dp
                        )
                    } else {
                        Text("Commit to Plan")
                    }
                }
            }
        }
    }
}

@Composable
fun BudgetBar(needsPct: Double, wantsPct: Double, savingsPct: Double) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(12.dp)
    ) {
        // Needs
        Box(
            modifier = Modifier
                .weight(needsPct.toFloat())
                .fillMaxHeight()
                .background(Color(0xFF4CAF50))
        )
        // Wants
        Box(
            modifier = Modifier
                .weight(wantsPct.toFloat())
                .fillMaxHeight()
                .background(Color(0xFF2196F3))
        )
        // Savings
        Box(
            modifier = Modifier
                .weight(savingsPct.toFloat())
                .fillMaxHeight()
                .background(Gold)
        )
    }
}

@Composable
fun BudgetItem(label: String, percentage: Double, color: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(color, shape = MaterialTheme.shapes.small)
            )
            Text(
                text = label,
                fontSize = 12.sp,
                color = Color.Gray
            )
        }
        Text(
            text = "${String.format("%.0f", percentage)}%",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
    }
}

@Composable
fun EmptyBudgetState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.FlightTakeoff,
            contentDescription = null,
            tint = Color.Gray.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Recommendations Available",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        
        Text(
            text = "Budget recommendations will appear here once you have spending data and goals set up.",
            fontSize = 14.sp,
            color = Color.Gray.copy(alpha = 0.7f)
        )
    }
}

@Composable
fun ErrorState(error: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.Error,
            contentDescription = null,
            tint = Color.Red.copy(alpha = 0.7f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "Unable to Load Recommendations",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )
        
        Text(
            text = error,
            fontSize = 14.sp,
            color = Color.Gray.copy(alpha = 0.7f)
        )
        
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(
                containerColor = Gold,
                contentColor = Color.Black
            )
        ) {
            Text("Retry")
        }
    }
}
