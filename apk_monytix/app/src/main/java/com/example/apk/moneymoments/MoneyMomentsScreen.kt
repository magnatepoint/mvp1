package com.example.apk.moneymoments

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
fun MoneyMomentsScreen(
    authViewModel: AuthViewModel
) {
    val authService = remember { AuthService(null) }
    val viewModel: MoneyMomentsViewModel = viewModel(
        factory = MoneyMomentsViewModelFactory(authService)
    )

    var selectedTab by remember { mutableStateOf(0) }
    val nudges by viewModel.nudges.collectAsState()
    val moments by viewModel.moments.collectAsState()
    val isNudgesLoading by viewModel.isNudgesLoading.collectAsState()
    val isMomentsLoading by viewModel.isMomentsLoading.collectAsState()

    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        viewModel.loadNudges()
        viewModel.loadMoments()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("MoneyMoments") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Charcoal,
                    titleContentColor = Color.White
                ),
                actions = {
                    IconButton(onClick = {
                        scope.launch {
                            viewModel.loadNudges()
                            viewModel.loadMoments()
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
        ) {
            // Custom Tab Bar
            TabRow(
                selectedTabIndex = selectedTab,
                containerColor = Charcoal,
                contentColor = Gold
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Nudges") },
                    selectedContentColor = Gold,
                    unselectedContentColor = Color.Gray
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Habits") },
                    selectedContentColor = Gold,
                    unselectedContentColor = Color.Gray
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("AI Insights") },
                    selectedContentColor = Gold,
                    unselectedContentColor = Color.Gray
                )
            }

            // Tab Content
            when (selectedTab) {
                0 -> NudgesTab(viewModel, nudges, isNudgesLoading)
                1 -> HabitsTab(viewModel, moments, isMomentsLoading)
                2 -> AIInsightsTab(viewModel, isMomentsLoading || isNudgesLoading)
            }
        }
    }
}

@Composable
fun NudgesTab(viewModel: MoneyMomentsViewModel, nudges: List<Nudge>, isLoading: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Your Nudges",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

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
            nudges.isEmpty() -> {
                EmptyState(
                    icon = Icons.Default.Message,
                    title = "No Nudges Yet",
                    message = "Financial nudges and suggestions will appear here"
                )
            }
            else -> {
                nudges.forEach { nudge ->
                    NudgeCard(nudge = nudge)
                }
            }
        }
    }
}

@Composable
fun HabitsTab(viewModel: MoneyMomentsViewModel, moments: List<MoneyMoment>, isLoading: Boolean) {
    val habits = remember(moments) { viewModel.getHabits() }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Your Financial Habits",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

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
            habits.isEmpty() -> {
                EmptyState(
                    icon = Icons.Default.AutoAwesome,
                    title = "No Habits Tracked",
                    message = "Your spending habits will be tracked and displayed here"
                )
            }
            else -> {
                habits.forEach { habit ->
                    HabitCard(habit = habit)
                }
            }
        }
    }
}

@Composable
fun AIInsightsTab(viewModel: MoneyMomentsViewModel, isLoading: Boolean) {
    val insights by remember { derivedStateOf { viewModel.getAIInsights() } }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "AI-Powered Insights",
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

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
            insights.isEmpty() -> {
                EmptyState(
                    icon = Icons.Default.Lightbulb,
                    title = "No Insights Yet",
                    message = "AI-powered insights and recommendations will appear here"
                )
            }
            else -> {
                insights.forEach { insight ->
                    AIInsightCard(insight = insight)
                }
            }
        }
    }
}

@Composable
fun NudgeCard(nudge: Nudge) {
    GlassCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = nudge.title ?: nudge.ruleName,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    modifier = Modifier.weight(1f)
                )
                
                Surface(
                    color = when (nudge.sendStatus) {
                        "sent" -> Color.Green.copy(alpha = 0.2f)
                        else -> Color.Gray.copy(alpha = 0.2f)
                    },
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        text = nudge.sendStatus.uppercase(),
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold,
                        color = when (nudge.sendStatus) {
                            "sent" -> Color.Green
                            else -> Color.Gray
                        }
                    )
                }
            }

            nudge.body?.let { body ->
                Text(
                    text = body,
                    fontSize = 14.sp,
                    color = Color.Gray.copy(alpha = 0.9f),
                    lineHeight = 20.sp
                )
            }
        }
    }
}

@Composable
fun HabitCard(habit: HabitItem) {
    GlassCard {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = habit.label,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        text = "${habit.monthsActive} months active",
                        fontSize = 12.sp,
                        color = Color.Gray
                    )
                }

                Surface(
                    color = Gold.copy(alpha = 0.2f),
                    shape = MaterialTheme.shapes.small
                ) {
                    Text(
                        text = "${(habit.confidence * 100).toInt()}%",
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = Gold
                    )
                }
            }

            Text(
                text = habit.insightText,
                fontSize = 14.sp,
                color = Color.Gray.copy(alpha = 0.9f),
                lineHeight = 20.sp
            )
        }
    }
}

@Composable
fun AIInsightCard(insight: AIInsight) {
    GlassCard {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Icon(
                imageVector = when (insight.type) {
                    "progress" -> Icons.Default.TrendingUp
                    "suggestion" -> Icons.Default.Lightbulb
                    else -> Icons.Default.Info
                },
                contentDescription = null,
                tint = Gold,
                modifier = Modifier.size(24.dp)
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = insight.type.replaceFirstChar { it.uppercase() },
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold,
                    color = Gold
                )
                Text(
                    text = insight.message,
                    fontSize = 14.sp,
                    color = Color.White,
                    lineHeight = 20.sp
                )
            }
        }
    }
}

@Composable
fun EmptyState(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, message: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.Gray.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = title,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        
        Text(
            text = message,
            fontSize = 14.sp,
            color = Color.Gray.copy(alpha = 0.7f)
        )
    }
}
