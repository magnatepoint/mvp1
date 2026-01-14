package com.example.apk.goals

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
fun GoalTrackerScreen(
    authViewModel: AuthViewModel
) {
    val authService = remember { AuthService(null) }
    val viewModel: GoalsViewModel = viewModel(
        factory = GoalsViewModelFactory(authService)
    )

    val currentStep by viewModel.currentStep.collectAsState()
    val progress by viewModel.progress.collectAsState()
    val isProgressLoading by viewModel.isProgressLoading.collectAsState()
    val progressError by viewModel.progressError.collectAsState()
    val selectedGoals by viewModel.selectedGoals.collectAsState()
    val lifeContext by viewModel.lifeContext.collectAsState()

    var hasGoals by remember { mutableStateOf(false) }
    var showQuestionnaire by remember { mutableStateOf(false) }
    var isCheckingGoals by remember { mutableStateOf(true) }

    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        isCheckingGoals = true
        hasGoals = viewModel.hasGoals()
        
        if (hasGoals) {
            viewModel.loadProgress()
        } else {
            showQuestionnaire = true
            viewModel.loadCatalog()
            viewModel.loadLifeContext()
        }
        
        isCheckingGoals = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("GoalTracker") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Charcoal,
                    titleContentColor = Color.White
                ),
                actions = {
                    if (hasGoals && !showQuestionnaire) {
                        IconButton(onClick = { showQuestionnaire = true }) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "Add Goal",
                                tint = Gold
                            )
                        }
                    }
                }
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .background(Charcoal)
        ) {
            when {
                isCheckingGoals -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(color = Gold)
                    }
                }
                showQuestionnaire -> {
                    GoalsQuestionnaireFlow(
                        viewModel = viewModel,
                        onComplete = {
                            showQuestionnaire = false
                            hasGoals = true
                            scope.launch {
                                viewModel.loadProgress()
                            }
                        },
                        onCancel = if (hasGoals) {
                            { showQuestionnaire = false }
                        } else null
                    )
                }
                else -> {
                    GoalProgressView(
                        viewModel = viewModel,
                        progress = progress,
                        isLoading = isProgressLoading,
                        error = progressError
                    )
                }
            }
        }
    }
}

@Composable
fun GoalProgressView(
    viewModel: GoalsViewModel,
    progress: List<GoalProgress>,
    isLoading: Boolean,
    error: String?
) {
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        // Header
        Column(
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = "Goal Progress Tracking",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = "Monitor your financial goals, track milestones, and see projected completion dates.",
                fontSize = 16.sp,
                color = Color.Gray.copy(alpha = 0.7f)
            )
        }

        when {
            isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 40.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Gold)
                }
            }
            error != null -> {
                ErrorState(
                    error = error,
                    onRetry = { scope.launch { viewModel.loadProgress() } }
                )
            }
            progress.isEmpty() -> {
                EmptyGoalsState()
            }
            else -> {
                progress.forEach { goalProgress ->
                    GoalProgressCard(goalProgress = goalProgress)
                }
            }
        }
    }
}

@Composable
fun GoalProgressCard(goalProgress: GoalProgress) {
    GlassCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = goalProgress.goalName,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            // Progress Bar
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "${String.format("%.1f", goalProgress.progressPct)}%",
                        fontSize = 14.sp,
                        color = Gold,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = "₹${String.format("%,.0f", goalProgress.currentSavingsClose)} saved",
                        fontSize = 14.sp,
                        color = Color.Gray
                    )
                }
                
                LinearProgressIndicator(
                    progress = (goalProgress.progressPct / 100).toFloat().coerceIn(0f, 1f),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp),
                    color = Gold,
                    trackColor = Color.Gray.copy(alpha = 0.3f)
                )
            }

            // Stats
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = "Remaining",
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                    Text(
                        text = "₹${String.format("%,.0f", goalProgress.remainingAmount)}",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium,
                        color = Color.White
                    )
                }
                
                goalProgress.projectedCompletionDate?.let { date ->
                    Column(
                        horizontalAlignment = Alignment.End
                    ) {
                        Text(
                            text = "Projected Completion",
                            fontSize = 12.sp,
                            color = Color.Gray
                        )
                        Text(
                            text = date,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium,
                            color = Color.White
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun EmptyGoalsState() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.TrackChanges,
            contentDescription = null,
            tint = Color.Gray.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Goals Yet",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        
        Text(
            text = "Set up your financial goals to start tracking progress.",
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
            text = "Unable to Load Progress",
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
