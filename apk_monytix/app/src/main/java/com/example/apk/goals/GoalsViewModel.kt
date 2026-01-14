package com.example.apk.goals

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.apk.auth.AuthService
import com.example.apk.config.Config
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
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

class GoalsViewModel(
    private val authService: AuthService = AuthService()
) : ViewModel() {
    
    private val client = OkHttpClient()
    private val gson = Gson()
    
    // Catalog
    private val _catalog = MutableStateFlow<List<GoalCatalogItem>>(emptyList())
    val catalog: StateFlow<List<GoalCatalogItem>> = _catalog.asStateFlow()
    
    private val _isCatalogLoading = MutableStateFlow(false)
    val isCatalogLoading: StateFlow<Boolean> = _isCatalogLoading.asStateFlow()
    
    private val _catalogError = MutableStateFlow<String?>(null)
    val catalogError: StateFlow<String?> = _catalogError.asStateFlow()
    
    // Life Context
    private val _lifeContext = MutableStateFlow<LifeContext?>(null)
    val lifeContext: StateFlow<LifeContext?> = _lifeContext.asStateFlow()
    
    private val _isContextLoading = MutableStateFlow(false)
    val isContextLoading: StateFlow<Boolean> = _isContextLoading.asStateFlow()
    
    // Progress
    private val _progress = MutableStateFlow<List<GoalProgress>>(emptyList())
    val progress: StateFlow<List<GoalProgress>> = _progress.asStateFlow()
    
    private val _isProgressLoading = MutableStateFlow(false)
    val isProgressLoading: StateFlow<Boolean> = _isProgressLoading.asStateFlow()
    
    private val _progressError = MutableStateFlow<String?>(null)
    val progressError: StateFlow<String?> = _progressError.asStateFlow()
    
    // Stepper State
    private val _currentStep = MutableStateFlow(1)
    val currentStep: StateFlow<Int> = _currentStep.asStateFlow()
    
    private val _selectedGoals = MutableStateFlow<List<SelectedGoal>>(emptyList())
    val selectedGoals: StateFlow<List<SelectedGoal>> = _selectedGoals.asStateFlow()
    
    private val _currentGoalIndex = MutableStateFlow(0)
    val currentGoalIndex: StateFlow<Int> = _currentGoalIndex.asStateFlow()
    
    private val _isSubmitting = MutableStateFlow(false)
    val isSubmitting: StateFlow<Boolean> = _isSubmitting.asStateFlow()
    
    private val _submitError = MutableStateFlow<String?>(null)
    val submitError: StateFlow<String?> = _submitError.asStateFlow()
    
    // MARK: - API Methods
    
    fun loadCatalog() {
        viewModelScope.launch {
            _isCatalogLoading.value = true
            _catalogError.value = null
            
            try {
                if (!authService.isAuthenticated() && authService.getCurrentSession() == null) {
                    throw Exception("Not authenticated")
                }
                
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}goals/catalog")
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        throw IOException("Error ${response.code}")
                    }
                    
                    val body = response.body?.string() ?: throw IOException("Empty response")
                    val catalogResponse = gson.fromJson(body, GoalCatalogResponse::class.java)
                    _catalog.value = catalogResponse.goals.sortedBy { it.displayOrder }
                }
            } catch (e: Exception) {
                android.util.Log.e("GoalsViewModel", "Error loading catalog", e)
                _catalogError.value = e.message ?: "Failed to load catalog"
                
                // If it's auth error, we might want to trigger logout or re-auth, but for now just error
            } finally {
                _isCatalogLoading.value = false
            }
        }
    }
    
    fun loadLifeContext() {
        viewModelScope.launch {
            _isContextLoading.value = true
            
            try {
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}goals/life-context")
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (response.isSuccessful) {
                        val body = response.body?.string() ?: "{}"
                        val contextResponse = gson.fromJson(body, LifeContextResponse::class.java)
                        _lifeContext.value = contextResponse.context
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("GoalsViewModel", "Error loading life context", e)
            } finally {
                _isContextLoading.value = false
            }
        }
    }
    
    fun loadProgress() {
        viewModelScope.launch {
            _isProgressLoading.value = true
            _progressError.value = null
            
            try {
                if (!authService.isAuthenticated() && authService.getCurrentSession() == null) {
                    throw Exception("Not authenticated")
                }
                
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}goals/progress")
                        .get()
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        throw IOException("Error ${response.code}")
                    }
                    
                    val body = response.body?.string() ?: throw IOException("Empty response")
                    val progressResponse = gson.fromJson(body, GoalsProgressResponse::class.java)
                    _progress.value = progressResponse.goals
                }
            } catch (e: Exception) {
                android.util.Log.e("GoalsViewModel", "Error loading progress", e)
                _progressError.value = e.message ?: "Failed to load progress"
            } finally {
                _isProgressLoading.value = false
            }
        }
    }
    
    suspend fun hasGoals(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val session = authService.getCurrentSession() ?: return@withContext false
                
                val request = Request.Builder()
                    .url("${Config.apiBaseUrl}goals/progress")
                    .get()
                    .addHeader("Authorization", "Bearer ${session.accessToken}")
                    .build()
                
                val response = client.newCall(request).execute()
                
                if (response.isSuccessful) {
                    val body = response.body?.string() ?: "{}"
                    val progressResponse = gson.fromJson(body, GoalsProgressResponse::class.java)
                    progressResponse.goals.isNotEmpty()
                } else {
                    false
                }
            } catch (e: Exception) {
                false
            }
        }
    }
    
    fun submitGoals(context: LifeContext) {
        viewModelScope.launch {
            _isSubmitting.value = true
            _submitError.value = null
            
            try {
                val session = authService.getCurrentSession()
                    ?: throw Exception("Not authenticated")
                
                withContext(Dispatchers.IO) {
                    val submitRequest = GoalsSubmitRequest(
                        context = context,
                        selectedGoals = _selectedGoals.value
                    )
                    
                    val json = gson.toJson(submitRequest)
                    val requestBody = json.toRequestBody("application/json".toMediaType())
                    
                    val request = Request.Builder()
                        .url("${Config.apiBaseUrl}goals/submit")
                        .post(requestBody)
                        .addHeader("Authorization", "Bearer ${session.accessToken}")
                        .addHeader("Content-Type", "application/json")
                        .build()
                    
                    val response = client.newCall(request).execute()
                    
                    if (!response.isSuccessful) {
                        val errorBody = response.body?.string() ?: "Unknown error"
                        throw IOException("Error ${response.code}: $errorBody")
                    }
                    
                    // Reset stepper state
                    _currentStep.value = 1
                    _selectedGoals.value = emptyList()
                    _currentGoalIndex.value = 0
                    
                    // Reload progress
                    loadProgress()
                }
            } catch (e: Exception) {
                android.util.Log.e("GoalsViewModel", "Error submitting goals", e)
                _submitError.value = e.message ?: "Failed to submit goals"
            } finally {
                _isSubmitting.value = false
            }
        }
    }
    
    // MARK: - Stepper Methods
    
    fun nextStep() {
        if (_currentStep.value < 4) {
            _currentStep.value += 1
        }
    }
    
    fun previousStep() {
        if (_currentStep.value > 1) {
            _currentStep.value -= 1
        }
    }
    
    fun addSelectedGoal(goal: GoalCatalogItem) {
        val newGoal = SelectedGoal(
            goalCategory = goal.goalCategory,
            goalName = goal.goalName
        )
        _selectedGoals.value = _selectedGoals.value + newGoal
    }
    
    fun removeSelectedGoal(index: Int) {
        val current = _selectedGoals.value.toMutableList()
        if (index < current.size) {
            current.removeAt(index)
            _selectedGoals.value = current
        }
    }
    
    fun updateSelectedGoal(index: Int, goal: SelectedGoal) {
        val current = _selectedGoals.value.toMutableList()
        if (index < current.size) {
            current[index] = goal
            _selectedGoals.value = current
        }
    }
    
    fun nextGoal() {
        if (_currentGoalIndex.value < _selectedGoals.value.size - 1) {
            _currentGoalIndex.value += 1
        }
    }
    
    fun previousGoal() {
        if (_currentGoalIndex.value > 0) {
            _currentGoalIndex.value -= 1
        }
    }
    
    fun updateLifeContext(context: LifeContext) {
        _lifeContext.value = context
    }
    
    fun groupedCatalog(): Map<String, List<GoalCatalogItem>> {
        return _catalog.value.groupBy { it.defaultHorizon }
    }
}

