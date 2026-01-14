package com.example.apk.console.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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

@Composable
fun AccountsTabView(viewModel: MolyConsoleViewModel) {
    val accounts by viewModel.accounts.collectAsStateWithLifecycle()
    val isLoading by viewModel.isAccountsLoading.collectAsStateWithLifecycle()
    val error by viewModel.accountsError.collectAsStateWithLifecycle()
    
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
            AccountsErrorState(error = errorMsg ?: "Unknown error") {
                viewModel.loadAccounts()
            }
        }
        accounts.isEmpty() -> {
            AccountsEmptyState()
        }
        else -> {
            AccountsContent(accounts = accounts)
        }
    }
}

@Composable
fun AccountsContent(accounts: List<com.example.apk.console.models.Account>) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp)
    ) {
        Text(
            text = "Your Accounts",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary,
            modifier = Modifier.fillMaxWidth()
        )
        
        accounts.forEach { account ->
            AccountCard(account = account)
        }
    }
}

@Composable
fun AccountCard(account: com.example.apk.console.models.Account) {
    GlassCard(
        padding = PaddingValues(20.dp),
        cornerRadius = 16.dp
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Account Icon
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .background(
                        getAccountTypeColor(account.accountType).copy(alpha = 0.2f),
                        androidx.compose.foundation.shape.CircleShape
                    ),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = getAccountTypeIcon(account.accountType),
                    contentDescription = null,
                    tint = getAccountTypeColor(account.accountType),
                    modifier = Modifier.size(24.dp)
                )
            }
            
            // Account Info
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = account.bankName,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
                
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = account.displayName,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = TextSecondary
                    )
                    
                    account.accountNumber?.let {
                        Text(
                            text = "• $it",
                            fontSize = 14.sp,
                            color = TextSecondary.copy(alpha = 0.5f)
                        )
                    }
                }
            }
            
            // Balance
            Text(
                text = formatCurrency(account.balance),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
        }
    }
}

@Composable
private fun AccountsErrorState(error: String, onRetry: () -> Unit) {
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
            text = "Unable to Load Accounts",
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
private fun AccountsEmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.CreditCard,
            contentDescription = null,
            tint = TextSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(48.dp)
        )
        
        Text(
            text = "No Accounts",
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold,
            color = TextPrimary
        )
        
        Text(
            text = "Link your bank accounts to see balances",
            fontSize = 14.sp,
            color = TextSecondary,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
    }
}


fun getAccountTypeIcon(type: com.example.apk.console.models.AccountType): androidx.compose.ui.graphics.vector.ImageVector {
    return when (type) {
        com.example.apk.console.models.AccountType.CHECKING -> Icons.Default.CreditCard
        com.example.apk.console.models.AccountType.SAVINGS -> Icons.Default.AccountBalance
        com.example.apk.console.models.AccountType.INVESTMENT -> Icons.Default.TrendingUp
        com.example.apk.console.models.AccountType.CREDIT -> Icons.Default.CreditCard
    }
}

fun getAccountTypeColor(type: com.example.apk.console.models.AccountType): Color {
    return when (type) {
        com.example.apk.console.models.AccountType.CHECKING -> Color(0xFF2196F3)
        com.example.apk.console.models.AccountType.SAVINGS -> Color(0xFF4CAF50)
        com.example.apk.console.models.AccountType.INVESTMENT -> Color(0xFF9C27B0)
        com.example.apk.console.models.AccountType.CREDIT -> Color(0xFFE53935)
    }
}

