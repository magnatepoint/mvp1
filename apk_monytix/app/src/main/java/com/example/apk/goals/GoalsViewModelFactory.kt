package com.example.apk.goals

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.apk.auth.AuthService

class GoalsViewModelFactory(
    private val authService: AuthService
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(GoalsViewModel::class.java)) {
            return GoalsViewModel(authService) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
