package com.example.apk.console

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.apk.auth.AuthViewModel
import com.example.apk.ui.components.WelcomeBanner
import com.example.apk.ui.theme.Charcoal
import com.example.apk.ui.theme.Gold

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConsoleScreen(
    authViewModel: AuthViewModel,
    viewModel: ConsoleViewModel = viewModel()
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("MolyConsole") },
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
            WelcomeBanner(
                username = authViewModel.userEmail,
                modifier = Modifier.padding(16.dp)
            )
            Text(
                text = "MolyConsole - Coming soon",
                modifier = Modifier.padding(16.dp)
            )
        }
    }
}

