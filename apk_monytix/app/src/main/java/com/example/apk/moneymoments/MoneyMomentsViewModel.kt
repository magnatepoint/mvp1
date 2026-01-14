package com.example.apk.moneymoments

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
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException

class MoneyMomentsViewModel(
    private val authService: AuthService = AuthService()
) : ViewModel() {
    
    private val client = OkHttpClient()
    private val gson = Gson()
    
    // Moments/Habits
    private val _moments = MutableStateFlow<List<MoneyMoment>>(emptyList())
    val moments: StateFlow<List<MoneyMoment>> = _moments.asStateFlow()
    
    private val _isMomentsLoading = MutableStateFlow(false)
    val isMomentsLoading: StateFlow<Boolean> = _isMomentsLoading.asStateFlow()
    
    private val _momentsError = MutableStateFlow<String?>(null)
    val momentsError: StateFlow<String?> = _momentsError.asStateFlow()
    
    // Nudges
    private val _nudges = MutableStateFlow<List<Nudge>>(emptyList())
    val nudges: StateFlow<List<Nudge>> = _nudges.asStateFlow()
    
    private val _isNudgesLoading = MutableStateFlow(false)
    val isNudgesLoading: StateFlow<Boolean> = _isNudgesLoading.asStateFlow()
    
    private val _nudgesError = MutableStateFlow<String?>(null)
    val nudgesError: StateFlow<String?> = _nudgesError.asStateFlow()
    
    // MARK: - API Methods
    
    fun loadMoments() {
        viewModelScope.launch {
            _isMomentsLoading.value = true
            _momentsError.value = null
            
            try {
                if (!authService.isAuthenticated() && authService.getCurrentSession() == null) {
                    throw Exception("Not authenticated")
                }
                
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}moneymoments/moments?all_months=true")
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        throw IOException("Error ${response.code}")
                    }
                    
                    val body = response.body?.string() ?: throw IOException("Empty response")
                    val momentsResponse = gson.fromJson(body, MoneyMomentsResponse::class.java)
                    _moments.value = momentsResponse.moments
                }
            } catch (e: Exception) {
                android.util.Log.e("MoneyMomentsViewModel", "Error loading moments", e)
                _momentsError.value = e.message ?: "Failed to load habits"
            } finally {
                _isMomentsLoading.value = false
            }
        }
    }
    
    fun loadNudges() {
        viewModelScope.launch {
            _isNudgesLoading.value = true
            _nudgesError.value = null
            
            try {
                if (!authService.isAuthenticated() && authService.getCurrentSession() == null) {
                    throw Exception("Not authenticated")
                }
                
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}moneymoments/nudges?limit=200")
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        throw IOException("Error ${response.code}")
                    }
                    
                    val body = response.body?.string() ?: throw IOException("Empty response")
                    val nudgesResponse = gson.fromJson(body, NudgesResponse::class.java)
                    _nudges.value = nudgesResponse.nudges
                }
            } catch (e: Exception) {
                android.util.Log.e("MoneyMomentsViewModel", "Error loading nudges", e)
                _nudgesError.value = e.message ?: "Failed to load nudges"
            } finally {
                _isNudgesLoading.value = false
            }
        }
    }
    
    // MARK: - Computed Properties
    
    fun getHabits(): List<HabitItem> {
        val grouped = _moments.value.groupBy { it.habitId }
        return grouped.map { (habitId, moments) ->
            val latest = moments.maxByOrNull { it.createdAt } ?: moments.first()
            HabitItem(
                id = habitId,
                label = latest.label,
                insightText = latest.insightText,
                confidence = latest.confidence,
                monthsActive = moments.map { it.month }.distinct().size
            )
        }.sortedByDescending { it.confidence }
    }
    
    fun getAIInsights(): List<AIInsight> {
        val insights = mutableListOf<AIInsight>()
        
        // High confidence moments
        _moments.value.filter { it.confidence >= 0.7 }.take(3).forEach { moment ->
            insights.add(
                AIInsight(
                    id = "moment_${moment.id}",
                    type = "progress",
                    message = "You've maintained ${(moment.confidence * 100).toInt()}% confidence in ${moment.label}. Keep it up!",
                    timestamp = moment.createdAt
                )
            )
        }
        
        // Nudges as insights
        _nudges.value.take(5).forEach { nudge ->
            insights.add(
                AIInsight(
                    id = "nudge_${nudge.id}",
                    type = "suggestion",
                    message = nudge.body ?: nudge.title ?: "",
                    timestamp = nudge.sentAt
                )
            )
        }
        
        return insights.sortedByDescending { it.timestamp }
    }
}

data class HabitItem(
    val id: String,
    val label: String,
    val insightText: String,
    val confidence: Double,
    val monthsActive: Int
)

data class AIInsight(
    val id: String,
    val type: String,
    val message: String,
    val timestamp: String
)

