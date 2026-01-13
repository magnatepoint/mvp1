package com.example.apk.spendsense

import com.example.apk.auth.AuthService
import com.example.apk.config.Config
import com.example.apk.spendsense.models.*
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.File
import java.util.concurrent.TimeUnit

class SpendSenseService(private val authService: AuthService) {
    private val gson: Gson = GsonBuilder()
        .setLenient()
        .create()

    private val okHttpClient: OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BODY
        })
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(Config.apiBaseUrl)
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create(gson))
        .build()

    private val api: SpendSenseApi = retrofit.create(SpendSenseApi::class.java)

    suspend fun getKPIs(month: String? = null): Result<SpendSenseKPIs> {
        return try {
            val session = authService.getCurrentSession()
            val token = try {
                session?.javaClass?.getMethod("getAccessToken")?.invoke(session) as? String
                    ?: session?.javaClass?.getField("accessToken")?.get(session) as? String
                    ?: return Result.failure(Exception("Not authenticated"))
            } catch (e: Exception) {
                return Result.failure(Exception("Not authenticated: ${e.message}"))
            }
            
            val response = api.getKPIs(month, "Bearer $token")
            if (response.isSuccessful) {
                response.body()?.let { Result.success(it) }
                    ?: Result.failure(Exception("Empty response"))
            } else {
                Result.failure(Exception("HTTP ${response.code()}: ${response.message()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getAvailableMonths(): Result<List<String>> {
        return try {
            val session = authService.getCurrentSession()
            val token = try {
                session?.javaClass?.getMethod("getAccessToken")?.invoke(session) as? String
                    ?: session?.javaClass?.getField("accessToken")?.get(session) as? String
                    ?: return Result.failure(Exception("Not authenticated"))
            } catch (e: Exception) {
                return Result.failure(Exception("Not authenticated: ${e.message}"))
            }
            
            val response = api.getAvailableMonths("Bearer $token")
            if (response.isSuccessful) {
                response.body()?.data?.let { Result.success(it) }
                    ?: Result.failure(Exception("Empty response"))
            } else {
                Result.failure(Exception("HTTP ${response.code()}: ${response.message()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getInsights(startDate: String? = null, endDate: String? = null): Result<Insights> {
        return try {
            val session = authService.getCurrentSession()
            val token = try {
                session?.javaClass?.getMethod("getAccessToken")?.invoke(session) as? String
                    ?: session?.javaClass?.getField("accessToken")?.get(session) as? String
                    ?: return Result.failure(Exception("Not authenticated"))
            } catch (e: Exception) {
                return Result.failure(Exception("Not authenticated: ${e.message}"))
            }
            
            val response = api.getInsights(startDate, endDate, "Bearer $token")
            if (response.isSuccessful) {
                response.body()?.let { Result.success(it) }
                    ?: Result.failure(Exception("Empty response"))
            } else {
                Result.failure(Exception("HTTP ${response.code()}: ${response.message()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getTransactions(
        limit: Int = 25,
        offset: Int = 0,
        search: String? = null,
        categoryCode: String? = null,
        subcategoryCode: String? = null,
        channel: String? = null
    ): Result<TransactionListResponse> {
        return try {
            val session = authService.getCurrentSession()
            val token = try {
                session?.javaClass?.getMethod("getAccessToken")?.invoke(session) as? String
                    ?: session?.javaClass?.getField("accessToken")?.get(session) as? String
                    ?: return Result.failure(Exception("Not authenticated"))
            } catch (e: Exception) {
                return Result.failure(Exception("Not authenticated: ${e.message}"))
            }
            
            val response = api.getTransactions(
                limit, offset, search, categoryCode, subcategoryCode, channel, "Bearer $token"
            )
            if (response.isSuccessful) {
                response.body()?.let { Result.success(it) }
                    ?: Result.failure(Exception("Empty response"))
            } else {
                Result.failure(Exception("HTTP ${response.code()}: ${response.message()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun uploadFile(
        file: File,
        password: String? = null
    ): Result<Map<String, Any>> {
        return try {
            val session = authService.getCurrentSession()
            val token = try {
                session?.javaClass?.getMethod("getAccessToken")?.invoke(session) as? String
                    ?: session?.javaClass?.getField("accessToken")?.get(session) as? String
                    ?: return Result.failure(Exception("Not authenticated"))
            } catch (e: Exception) {
                return Result.failure(Exception("Not authenticated: ${e.message}"))
            }
            
            val requestFile = file.asRequestBody("application/octet-stream".toMediaType())
            val filePart = MultipartBody.Part.createFormData("file", file.name, requestFile)
            
            val passwordPart = password?.let {
                it.toRequestBody("text/plain".toMediaType())
            }
            
            val response = api.uploadFile(filePart, passwordPart, "Bearer $token")
            if (response.isSuccessful) {
                Result.success(mapOf("status" to "success"))
            } else {
                Result.failure(Exception("HTTP ${response.code()}: ${response.message()}"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

