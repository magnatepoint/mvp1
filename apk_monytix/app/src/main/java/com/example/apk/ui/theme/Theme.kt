package com.example.apk.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkCharcoalColorScheme = darkColorScheme(
    primary = Gold,
    onPrimary = Charcoal,
    secondary = GoldDark,
    onSecondary = TextPrimary,
    tertiary = Gold,
    onTertiary = Charcoal,
    background = Charcoal,
    onBackground = TextPrimary,
    surface = DarkCharcoal,
    onSurface = TextPrimary,
    surfaceVariant = DarkCharcoal,
    onSurfaceVariant = TextSecondary,
    error = Error,
    onError = TextPrimary,
    errorContainer = Error.copy(alpha = 0.2f),
    onErrorContainer = Error,
    outline = TextTertiary,
    outlineVariant = TextTertiary.copy(alpha = 0.5f)
)

@Composable
fun ApkTheme(
    darkTheme: Boolean = true, // Always use dark theme
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkCharcoalColorScheme,
        typography = Typography,
        content = content
    )
}