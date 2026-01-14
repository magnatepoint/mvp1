package com.example.apk.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.apk.auth.AuthService

class SettingsViewModelFactory(
    private val authService: AuthService
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(SettingsViewModel::class.java)) {
            return SettingsViewModel(authService) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
