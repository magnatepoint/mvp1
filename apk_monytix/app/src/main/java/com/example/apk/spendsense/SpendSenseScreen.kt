package com.example.apk.spendsense

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.auth.AuthViewModel
import com.example.apk.ui.components.WelcomeBanner
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.Gold
import com.example.apk.spendsense.views.CategoriesTabView
import com.example.apk.spendsense.views.TransactionsTabView
import com.example.apk.spendsense.views.InsightsTabView

enum class SpendSenseTab(val label: String) {
    CATEGORIES("Categories"),
    TRANSACTIONS("Transactions"),
    INSIGHTS("Insights")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SpendSenseScreen(
    authViewModel: AuthViewModel,
    viewModel: SpendSenseViewModel = viewModel()
) {
    var selectedTab by remember { mutableStateOf(SpendSenseTab.CATEGORIES) }

    LaunchedEffect(Unit) {
        viewModel.loadKPIs()
        viewModel.loadAvailableMonths()
        viewModel.loadTransactions()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("SpendSense") },
                actions = {
                    IconButton(onClick = { /* Handle menu */ }) {
                        Icon(Icons.Default.MoreVert, contentDescription = "More")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Charcoal,
                    titleContentColor = androidx.compose.ui.graphics.Color.White
                )
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
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
            )

            // Custom Tab Bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                SpendSenseTab.entries.forEach { tab ->
                    TabButton(
                        label = tab.label,
                        isSelected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            HorizontalDivider(color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.2f))

            // Tab Content
            when (selectedTab) {
                SpendSenseTab.CATEGORIES -> CategoriesTabView(viewModel)
                SpendSenseTab.TRANSACTIONS -> TransactionsTabView(viewModel)
                SpendSenseTab.INSIGHTS -> InsightsTabView(viewModel)
            }
        }
    }
}

@Composable
fun TabButton(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp)
            .fillMaxWidth(),
        horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
            color = if (isSelected) Gold else androidx.compose.ui.graphics.Color.White.copy(alpha = 0.7f)
        )
        Spacer(modifier = Modifier.height(8.dp))
        if (isSelected) {
            HorizontalDivider(
                modifier = Modifier
                    .fillMaxWidth(0.5f)
                    .height(3.dp),
                color = Gold,
                thickness = 3.dp
            )
        }
    }
}

