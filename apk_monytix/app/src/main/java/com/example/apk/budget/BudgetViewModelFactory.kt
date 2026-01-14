package com.example.apk.budget

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.apk.auth.AuthService

class BudgetViewModelFactory(
    private val authService: AuthService
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(BudgetViewModel::class.java)) {
            return BudgetViewModel(authService) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
