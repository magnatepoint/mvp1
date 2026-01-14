package com.example.apk.budget

import com.google.gson.annotations.SerializedName

// MARK: - Budget Recommendation

data class BudgetRecommendation(
    @SerializedName("plan_code") val planCode: String,
    @SerializedName("name") val name: String,
    @SerializedName("description") val description: String?,
    @SerializedName("needs_budget_pct") val needsBudgetPct: Double,
    @SerializedName("wants_budget_pct") val wantsBudgetPct: Double,
    @SerializedName("savings_budget_pct") val savingsBudgetPct: Double,
    @SerializedName("score") val score: Double,
    @SerializedName("recommendation_reason") val recommendationReason: String,
    @SerializedName("goal_preview") val goalPreview: List<GoalAllocationPreview>?
)

data class GoalAllocationPreview(
    @SerializedName("goal_id") val goalId: String,
    @SerializedName("goal_name") val goalName: String,
    @SerializedName("allocation_pct") val allocationPct: Double,
    @SerializedName("allocation_amount") val allocationAmount: Double
)

// MARK: - Budget Commit

data class BudgetCommitRequest(
    @SerializedName("plan_code") val planCode: String,
    @SerializedName("month") val month: String? = null,
    @SerializedName("goal_allocations") val goalAllocations: Map<String, Double>? = null,
    @SerializedName("notes") val notes: String? = null
)

data class GoalAllocation(
    @SerializedName("ubcga_id") val ubcgaId: String,
    @SerializedName("user_id") val userId: String,
    @SerializedName("month") val month: String,
    @SerializedName("goal_id") val goalId: String,
    @SerializedName("goal_name") val goalName: String?,
    @SerializedName("weight_pct") val weightPct: Double,
    @SerializedName("planned_amount") val plannedAmount: Double,
    @SerializedName("created_at") val createdAt: String
)

data class CommittedBudget(
    @SerializedName("user_id") val userId: String,
    @SerializedName("month") val month: String,
    @SerializedName("plan_code") val planCode: String,
    @SerializedName("alloc_needs_pct") val allocNeedsPct: Double,
    @SerializedName("alloc_wants_pct") val allocWantsPct: Double,
    @SerializedName("alloc_assets_pct") val allocAssetsPct: Double,
    @SerializedName("notes") val notes: String?,
    @SerializedName("committed_at") val committedAt: String,
    @SerializedName("goal_allocations") val goalAllocations: List<GoalAllocation>
)

// MARK: - API Responses

data class BudgetRecommendationsResponse(
    @SerializedName("recommendations") val recommendations: List<BudgetRecommendation>
)

data class BudgetCommitResponse(
    @SerializedName("status") val status: String,
    @SerializedName("budget") val budget: CommittedBudget
)

data class CommittedBudgetResponse(
    @SerializedName("status") val status: String,
    @SerializedName("budget") val budget: CommittedBudget?
)
