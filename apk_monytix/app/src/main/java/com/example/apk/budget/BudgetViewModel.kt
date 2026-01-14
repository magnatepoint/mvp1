package com.example.apk.budget

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.apk.auth.AuthService
import com.example.apk.config.Config
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

class BudgetViewModel(
    private val authService: AuthService = AuthService()
) : ViewModel() {
    
    private val client = OkHttpClient()
    private val gson = Gson()
    
    // Recommendations
    private val _recommendations = MutableStateFlow<List<BudgetRecommendation>>(emptyList())
    val recommendations: StateFlow<List<BudgetRecommendation>> = _recommendations.asStateFlow()
    
    private val _isRecommendationsLoading = MutableStateFlow(false)
    val isRecommendationsLoading: StateFlow<Boolean> = _isRecommendationsLoading.asStateFlow()
    
    private val _recommendationsError = MutableStateFlow<String?>(null)
    val recommendationsError: StateFlow<String?> = _recommendationsError.asStateFlow()
    
    // Committed Budget
    private val _committedBudget = MutableStateFlow<CommittedBudget?>(null)
    val committedBudget: StateFlow<CommittedBudget?> = _committedBudget.asStateFlow()
    
    private val _isCommittedLoading = MutableStateFlow(false)
    val isCommittedLoading: StateFlow<Boolean> = _isCommittedLoading.asStateFlow()
    
    // Commit Action
    private val _isCommitting = MutableStateFlow(false)
    val isCommitting: StateFlow<Boolean> = _isCommitting.asStateFlow()
    
    private val _commitError = MutableStateFlow<String?>(null)
    val commitError: StateFlow<String?> = _commitError.asStateFlow()
    
    // MARK: - API Methods
    
    fun loadRecommendations(month: String? = null) {
        viewModelScope.launch {
            _isRecommendationsLoading.value = true
            _recommendationsError.value = null
            
            try {
                // Wait for auth if needed or check if authenticated
                if (!authService.isAuthenticated()) {
                     // Could retry or verify if session loading
                     // For now, if current session is null, we try one more check
                     if (authService.getCurrentSession() == null) {
                         throw Exception("Not authenticated")
                     }
                }
                
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val url = if (month != null) {
                        "${Config.apiBaseUrl}budget/recommendations?month=$month"
                    } else {
                        "${Config.apiBaseUrl}budget/recommendations"
                    }
                    
                    val request = Request.Builder()
                        .url(url)
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        throw IOException("Error ${response.code}")
                    }
                    
                    val body = response.body?.string() ?: throw IOException("Empty response")
                    val recommendationsResponse = gson.fromJson(body, BudgetRecommendationsResponse::class.java)
                    _recommendations.value = recommendationsResponse.recommendations.sortedByDescending { it.score }
                }
            } catch (e: Exception) {
                android.util.Log.e("BudgetViewModel", "Error loading recommendations", e)
                _recommendationsError.value = e.message ?: "Failed to load recommendations"
            } finally {
                _isRecommendationsLoading.value = false
            }
        }
    }
    
    fun loadCommittedBudget(month: String? = null) {
        viewModelScope.launch {
            _isCommittedLoading.value = true
            
            try {
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val url = if (month != null) {
                        "${Config.apiBaseUrl}budget/committed?month=$month"
                    } else {
                        "${Config.apiBaseUrl}budget/committed"
                    }
                    
                    val request = Request.Builder()
                        .url(url)
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (response.isSuccessful) {
                        val body = response.body?.string() ?: "{}"
                        val committedResponse = gson.fromJson(body, CommittedBudgetResponse::class.java)
                        _committedBudget.value = committedResponse.budget
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("BudgetViewModel", "Error loading committed budget", e)
            } finally {
                _isCommittedLoading.value = false
            }
        }
    }
    
    fun commitToPlan(
        planCode: String,
        month: String? = null,
        goalAllocations: Map<String, Double>? = null,
        notes: String? = null
    ) {
        viewModelScope.launch {
            _isCommitting.value = true
            _commitError.value = null
            
            try {
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val commitRequest = BudgetCommitRequest(
                        planCode = planCode,
                        month = month,
                        goalAllocations = goalAllocations,
                        notes = notes
                    )
                    
                    val json = gson.toJson(commitRequest)
                    val requestBody = json.toRequestBody("application/json".toMediaType())
                    
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}budget/commit")
                        .post(requestBody)
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .addHeader("Content-Type", "application/json")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: "Unknown error"
                        throw IOException("Error ${response.code}: $errorBody")
                    }
                    
                    val body = response.body?.string() ?: throw IOException("Empty response")
                    val commitResponse = gson.fromJson(body, BudgetCommitResponse::class.java)
                    _committedBudget.value = commitResponse.budget
                    
                    // Reload recommendations
                    loadRecommendations(month)
                }
            } catch (e: Exception) {
                android.util.Log.e("BudgetViewModel", "Error committing budget", e)
                _commitError.value = e.message ?: "Failed to commit budget"
            } finally {
                _isCommitting.value = false
            }
        }
    }
}

