package com.example.apk.console

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.horizontalScroll
import androidx.compose.ui.graphics.Color
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.auth.AuthViewModel
import com.example.apk.console.tabs.*
import com.example.apk.ui.components.WelcomeBanner
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.DarkCharcoal
import com.example.apk.ui.theme.Gold
import com.example.apk.ui.theme.TextPrimary
import com.example.apk.ui.theme.TextSecondary

enum class MolyConsoleTab(
    val label: String,
    val icon: ImageVector
) {
    OVERVIEW("Overview", Icons.Default.BarChart),
    ACCOUNTS("Accounts", Icons.Default.CreditCard),
    SPENDING("Spending", Icons.Default.AttachMoney),
    GOALS("Goals", Icons.Default.TrackChanges),
    AI_INSIGHT("AI Insight", Icons.Default.AutoAwesome)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MolyConsoleScreen(
    authViewModel: AuthViewModel,
    viewModel: MolyConsoleViewModel = viewModel {
        // Create AuthService and SpendSenseService for the ViewModel
        val authService = com.example.apk.auth.AuthService()
        MolyConsoleViewModel(authService)
    }
) {
    var selectedTab by remember { mutableStateOf(MolyConsoleTab.OVERVIEW) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        "MolyConsole",
                        fontWeight = FontWeight.Bold,
                        fontSize = 20.sp
                    ) 
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Charcoal,
                    titleContentColor = TextPrimary
                ),
                actions = {
                    IconButton(onClick = { /* Refresh */ }) {
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
            // Welcome Banner
            WelcomeBanner(
                username = authViewModel.userEmail,
                modifier = Modifier.padding(vertical = 8.dp)
            )
            
            // Custom Tab Bar
            CustomTabBar(
                selectedTab = selectedTab,
                onTabSelected = { selectedTab = it },
                modifier = Modifier.fillMaxWidth()
            )
            
            // Tab Content
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Charcoal)
            ) {
                when (selectedTab) {
                    MolyConsoleTab.OVERVIEW -> OverviewTabView(viewModel = viewModel)
                    MolyConsoleTab.ACCOUNTS -> AccountsTabView(viewModel = viewModel)
                    MolyConsoleTab.SPENDING -> SpendingTabView(viewModel = viewModel)
                    MolyConsoleTab.GOALS -> GoalsTabView(viewModel = viewModel)
                    MolyConsoleTab.AI_INSIGHT -> AIInsightTabView(viewModel = viewModel)
                }
            }
        }
    }
}

@Composable
fun CustomTabBar(
    selectedTab: MolyConsoleTab,
    onTabSelected: (MolyConsoleTab) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .background(Charcoal)
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 8.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        MolyConsoleTab.values().forEach { tab ->
            TabButton(
                tab = tab,
                isSelected = selectedTab == tab,
                onClick = { onTabSelected(tab) }
            )
        }
    }
    
    // Divider
    HorizontalDivider(
        color = TextSecondary.copy(alpha = 0.2f),
        thickness = 1.dp
    )
}

@Composable
fun TabButton(
    tab: MolyConsoleTab,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .width(80.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(
                if (isSelected) Gold.copy(alpha = 0.2f) else DarkCharcoal
            )
            .padding(vertical = 12.dp)
            .then(
                if (isSelected) {
                    Modifier.border(
                        width = 1.dp,
                        color = Gold,
                        shape = RoundedCornerShape(8.dp)
                    )
                } else {
                    Modifier.border(
                        width = 1.dp,
                        color = TextSecondary.copy(alpha = 0.3f),
                        shape = RoundedCornerShape(8.dp)
                    )
                }
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Icon(
            imageVector = tab.icon,
            contentDescription = tab.label,
            tint = if (isSelected) Gold else TextSecondary.copy(alpha = 0.7f),
            modifier = Modifier.size(18.dp)
        )
        
        Text(
            text = tab.label,
            fontSize = 12.sp,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isSelected) Gold else TextSecondary.copy(alpha = 0.7f)
        )
        
        // Indicator dot
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(if (isSelected) Gold else Color.Transparent)
        )
    }
}

