package com.example.apk.spendsense

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.apk.auth.AuthService
import com.example.apk.spendsense.models.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SpendSenseViewModel(
    private val authService: AuthService = AuthService()
) : ViewModel() {
    private val spendSenseService = SpendSenseService(authService)

    // KPIs
    private val _kpis = MutableStateFlow<SpendSenseKPIs?>(null)
    val kpis: StateFlow<SpendSenseKPIs?> = _kpis.asStateFlow()

    private val _isKPIsLoading = MutableStateFlow(false)
    val isKPIsLoading: StateFlow<Boolean> = _isKPIsLoading.asStateFlow()

    private val _kpisError = MutableStateFlow<String?>(null)
    val kpisError: StateFlow<String?> = _kpisError.asStateFlow()

    // Available months
    private val _availableMonths = MutableStateFlow<List<String>>(emptyList())
    val availableMonths: StateFlow<List<String>> = _availableMonths.asStateFlow()

    // Transactions
    private val _transactions = MutableStateFlow<List<Transaction>>(emptyList())
    val transactions: StateFlow<List<Transaction>> = _transactions.asStateFlow()

    private val _totalTransactions = MutableStateFlow(0)
    val totalTransactions: StateFlow<Int> = _totalTransactions.asStateFlow()

    private val _isTransactionsLoading = MutableStateFlow(false)
    val isTransactionsLoading: StateFlow<Boolean> = _isTransactionsLoading.asStateFlow()

    private val _transactionsError = MutableStateFlow<String?>(null)
    val transactionsError: StateFlow<String?> = _transactionsError.asStateFlow()

    // Insights
    private val _insights = MutableStateFlow<Insights?>(null)
    val insights: StateFlow<Insights?> = _insights.asStateFlow()

    private val _isInsightsLoading = MutableStateFlow(false)
    val isInsightsLoading: StateFlow<Boolean> = _isInsightsLoading.asStateFlow()

    private val _insightsError = MutableStateFlow<String?>(null)
    val insightsError: StateFlow<String?> = _insightsError.asStateFlow()

    // File upload
    private val _isUploading = MutableStateFlow(false)
    val isUploading: StateFlow<Boolean> = _isUploading.asStateFlow()

    private val _uploadProgress = MutableStateFlow(0f)
    val uploadProgress: StateFlow<Float> = _uploadProgress.asStateFlow()

    private val _uploadError = MutableStateFlow<String?>(null)
    val uploadError: StateFlow<String?> = _uploadError.asStateFlow()

    fun loadKPIs(month: String? = null) {
        viewModelScope.launch {
            _isKPIsLoading.value = true
            _kpisError.value = null
            try {
                spendSenseService.getKPIs(month).fold(
                    onSuccess = { kpis ->
                        _kpis.value = kpis
                    },
                    onFailure = { error ->
                        _kpisError.value = error.message ?: "Failed to load KPIs"
                    }
                )
            } catch (e: Exception) {
                _kpisError.value = e.message ?: "Failed to load KPIs"
            } finally {
                _isKPIsLoading.value = false
            }
        }
    }

    fun loadAvailableMonths() {
        viewModelScope.launch {
            try {
                spendSenseService.getAvailableMonths().fold(
                    onSuccess = { months ->
                        _availableMonths.value = months
                    },
                    onFailure = { error ->
                        // Silently fail - not critical
                    }
                )
            } catch (e: Exception) {
                // Silently fail
            }
        }
    }

    fun loadTransactions(
        limit: Int = 25,
        offset: Int = 0,
        search: String? = null,
        categoryCode: String? = null,
        subcategoryCode: String? = null,
        channel: String? = null
    ) {
        viewModelScope.launch {
            _isTransactionsLoading.value = true
            _transactionsError.value = null
            try {
                spendSenseService.getTransactions(
                    limit, offset, search, categoryCode, subcategoryCode, channel
                ).fold(
                    onSuccess = { response ->
                        _transactions.value = response.transactions
                        _totalTransactions.value = response.total
                    },
                    onFailure = { error ->
                        _transactionsError.value = error.message ?: "Failed to load transactions"
                    }
                )
            } catch (e: Exception) {
                _transactionsError.value = e.message ?: "Failed to load transactions"
            } finally {
                _isTransactionsLoading.value = false
            }
        }
    }

    fun loadInsights(startDate: String? = null, endDate: String? = null) {
        viewModelScope.launch {
            _isInsightsLoading.value = true
            _insightsError.value = null
            try {
                spendSenseService.getInsights(startDate, endDate).fold(
                    onSuccess = { insights ->
                        _insights.value = insights
                    },
                    onFailure = { error ->
                        _insightsError.value = error.message ?: "Failed to load insights"
                    }
                )
            } catch (e: Exception) {
                _insightsError.value = e.message ?: "Failed to load insights"
            } finally {
                _isInsightsLoading.value = false
            }
        }
    }

    fun uploadFile(file: java.io.File, password: String? = null) {
        viewModelScope.launch {
            _isUploading.value = true
            _uploadError.value = null
            _uploadProgress.value = 0f
            try {
                spendSenseService.uploadFile(file, password).fold(
                    onSuccess = {
                        _uploadProgress.value = 1f
                        // Reload data after successful upload
                        loadKPIs()
                        loadTransactions()
                    },
                    onFailure = { error ->
                        _uploadError.value = error.message ?: "Failed to upload file"
                    }
                )
            } catch (e: Exception) {
                _uploadError.value = e.message ?: "Failed to upload file"
            } finally {
                _isUploading.value = false
            }
        }
    }
}


