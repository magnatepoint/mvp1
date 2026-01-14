package com.example.apk.spendsense

import com.example.apk.spendsense.models.*
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

interface SpendSenseApi {
    @GET("/v1/spendsense/kpis")
    suspend fun getKPIs(
        @Query("month") month: String? = null,
        @Header("Authorization") authToken: String
    ): Response<SpendSenseKPIs>

    @GET("/v1/spendsense/kpis/available-months")
    suspend fun getAvailableMonths(
        @Header("Authorization") authToken: String
    ): Response<AvailableMonthsResponse>

    @GET("/v1/spendsense/insights")
    suspend fun getInsights(
        @Query("start_date") startDate: String? = null,
        @Query("end_date") endDate: String? = null,
        @Header("Authorization") authToken: String
    ): Response<Insights>

    @GET("/v1/spendsense/transactions")
    suspend fun getTransactions(
        @Query("limit") limit: Int = 25,
        @Query("offset") offset: Int = 0,
        @Query("search") search: String? = null,
        @Query("category_code") categoryCode: String? = null,
        @Query("subcategory_code") subcategoryCode: String? = null,
        @Query("channel") channel: String? = null,
        @Header("Authorization") authToken: String
    ): Response<TransactionListResponse>

    @Multipart
    @POST("/v1/spendsense/uploads/file")
    suspend fun uploadFile(
        @Part file: MultipartBody.Part,
        @Part("password") password: RequestBody? = null,
        @Header("Authorization") authToken: String
    ): Response<ResponseBody>
}


