package com.example.apk.moneymoments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.apk.auth.AuthService

class MoneyMomentsViewModelFactory(
    private val authService: AuthService
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(MoneyMomentsViewModel::class.java)) {
            return MoneyMomentsViewModel(authService) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
