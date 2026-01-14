package com.example.apk.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.apk.ui.theme.Error
import com.example.apk.ui.theme.TextPrimary

@Composable
fun ErrorView(
    message: String,
    onRetry: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Icon(
            imageVector = Icons.Default.ErrorOutline,
            contentDescription = "Error",
            tint = Error,
            modifier = Modifier.size(48.dp)
        )
        Text(
            text = "Error",
            style = MaterialTheme.typography.titleLarge,
            color = TextPrimary
        )
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = TextPrimary.copy(alpha = 0.8f),
            textAlign = TextAlign.Center
        )
        onRetry?.let {
            Button(
                onClick = it,
                colors = ButtonDefaults.buttonColors(
                    containerColor = Error
                )
            ) {
                Text("Retry")
            }
        }
    }
}

