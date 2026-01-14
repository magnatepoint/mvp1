package com.example.apk.moneymoments

import com.google.gson.annotations.SerializedName

// MARK: - MoneyMoment/Habit

data class MoneyMoment(
    @SerializedName("user_id") val userId: String,
    @SerializedName("month") val month: String,
    @SerializedName("habit_id") val habitId: String,
    @SerializedName("value") val value: Double,
    @SerializedName("label") val label: String,
    @SerializedName("insight_text") val insightText: String,
    @SerializedName("confidence") val confidence: Double,
    @SerializedName("created_at") val createdAt: String
) {
    val id: String get() = habitId
}

// MARK: - Nudge

data class Nudge(
    @SerializedName("delivery_id") val deliveryId: String,
    @SerializedName("user_id") val userId: String,
    @SerializedName("rule_id") val ruleId: String,
    @SerializedName("template_code") val templateCode: String,
    @SerializedName("channel") val channel: String,
    @SerializedName("sent_at") val sentAt: String,
    @SerializedName("send_status") val sendStatus: String,
    @SerializedName("title") val title: String?,
    @SerializedName("body") val body: String?,
    @SerializedName("cta_text") val ctaText: String?,
    @SerializedName("rule_name") val ruleName: String
) {
    val id: String get() = deliveryId
}

// MARK: - API Responses

data class MoneyMomentsResponse(
    @SerializedName("moments") val moments: List<MoneyMoment>
)

data class NudgesResponse(
    @SerializedName("nudges") val nudges: List<Nudge>
)
