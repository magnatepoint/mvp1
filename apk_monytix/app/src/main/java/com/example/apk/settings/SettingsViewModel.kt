package com.example.apk.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.apk.auth.AuthService
import com.example.apk.config.Config
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException

class SettingsViewModel(
    private val authService: AuthService
) : ViewModel() {
    private val _userId = MutableStateFlow<String?>(null)
    val userId: StateFlow<String?> = _userId.asStateFlow()

    private val _isDeleting = MutableStateFlow(false)
    val isDeleting: StateFlow<Boolean> = _isDeleting.asStateFlow()

    private val _deleteError = MutableStateFlow<String?>(null)
    val deleteError: StateFlow<String?> = _deleteError.asStateFlow()

    private val client = OkHttpClient()

    fun loadUserInfo() {
        viewModelScope.launch {
            try {
                val user = authService.getCurrentUser()
                _userId.value = user?.id
            } catch (e: Exception) {
                android.util.Log.e("SettingsViewModel", "Error loading user info", e)
            }
        }
    }

    fun deleteAllData() {
        viewModelScope.launch {
            _isDeleting.value = true
            _deleteError.value = null

            try {
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")

                val request = Request.Builder()
                    .url("${Config.apiBaseUrl}spendsense/data")
                    .delete()
                    .addHeader("Content-Type", "application/json")
                    .addHeader("Authorization", "Bearer ${session.accessToken}")
                    .build()

                val response = client.newCall(request).execute()

                if (!response.isSuccessful) {
                    val errorBody = response.body?.string() ?: "Unknown error"
                    throw IOException("Error ${response.code}: $errorBody")
                }

                // Success
                _deleteError.value = null
                android.util.Log.d("SettingsViewModel", "Successfully deleted all data")
            } catch (e: Exception) {
                android.util.Log.e("SettingsViewModel", "Error deleting data", e)
                _deleteError.value = e.message ?: "Failed to delete data"
            } finally {
                _isDeleting.value = false
            }
        }
    }

    fun clearDeleteError() {
        _deleteError.value = null
    }
}
