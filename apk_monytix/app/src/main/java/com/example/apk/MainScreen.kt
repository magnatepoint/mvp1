package com.example.apk

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.auth.AuthViewModel
import com.example.apk.ui.theme.Gold
import com.example.apk.spendsense.SpendSenseScreen
import com.example.apk.console.MolyConsoleScreen
import com.example.apk.goals.GoalTrackerScreen
import com.example.apk.budget.BudgetPilotScreen
import com.example.apk.moneymoments.MoneyMomentsScreen
import com.example.apk.settings.SettingsScreen

@Composable
fun MainScreen(
    authViewModel: AuthViewModel = viewModel()
) {
    var selectedTab by remember { mutableStateOf(MainTab.MOLYCONSOLE) }

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = androidx.compose.ui.graphics.Color(0xFF262626)
            ) {
                MainTab.entries.forEach { tab ->
                    NavigationBarItem(
                        icon = {
                            Icon(
                                imageVector = tab.icon,
                                contentDescription = tab.label
                            )
                        },
                        label = { Text(tab.label) },
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Gold,
                            selectedTextColor = Gold,
                            indicatorColor = Gold.copy(alpha = 0.2f),
                            unselectedIconColor = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.7f),
                            unselectedTextColor = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.7f)
                        )
                    )
                }
            }
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when (selectedTab) {
                MainTab.MOLYCONSOLE -> {
                    MolyConsoleScreen(authViewModel = authViewModel)
                }
                MainTab.SPENDSENSE -> {
                    SpendSenseScreen(authViewModel = authViewModel)
                }
                MainTab.GOALTRACKER -> {
                    GoalTrackerScreen(authViewModel = authViewModel)
                }
                MainTab.BUDGETPILOT -> {
                    BudgetPilotScreen(authViewModel = authViewModel)
                }
                MainTab.MONEYMOMENTS -> {
                    MoneyMomentsScreen(authViewModel = authViewModel)
                }
                MainTab.SETTINGS -> {
                    SettingsScreen(authViewModel = authViewModel)
                }
            }
        }
    }
}

enum class MainTab(
    val label: String,
    val icon: ImageVector
) {
    MOLYCONSOLE("MolyConsole", Icons.Default.Dashboard),
    SPENDSENSE("SpendSense", Icons.Default.BarChart),
    GOALTRACKER("GoalTracker", Icons.Default.TrackChanges),
    BUDGETPILOT("BudgetPilot", Icons.Default.FlightTakeoff),
    MONEYMOMENTS("MoneyMoments", Icons.Default.AutoAwesome),
    SETTINGS("Settings", Icons.Default.Settings)
}

