package com.example.apk.goals

import com.google.gson.annotations.SerializedName
import java.util.UUID

// MARK: - Goal Catalog

data class GoalCatalogItem(
    @SerializedName("goal_category") val goalCategory: String,
    @SerializedName("goal_name") val goalName: String,
    @SerializedName("default_horizon") val defaultHorizon: String,
    @SerializedName("policy_linked_txn_type") val policyLinkedTxnType: String,
    @SerializedName("is_mandatory_flag") val isMandatoryFlag: Boolean,
    @SerializedName("suggested_min_amount_formula") val suggestedMinAmountFormula: String?,
    @SerializedName("display_order") val displayOrder: Int
)

// MARK: - Life Context

data class LifeContext(
    @SerializedName("age_band") val ageBand: String,
    @SerializedName("dependents_spouse") val dependentsSpouse: Boolean,
    @SerializedName("dependents_children_count") val dependentsChildrenCount: Int,
    @SerializedName("dependents_parents_care") val dependentsParentsCare: Boolean,
    @SerializedName("housing") val housing: String,
    @SerializedName("employment") val employment: String,
    @SerializedName("income_regularity") val incomeRegularity: String,
    @SerializedName("region_code") val regionCode: String,
    @SerializedName("emergency_opt_out") val emergencyOptOut: Boolean,
    @SerializedName("monthly_investible_capacity") val monthlyInvestibleCapacity: Double? = null,
    @SerializedName("total_monthly_emi_obligations") val totalMonthlyEMIObligations: Double? = null,
    @SerializedName("risk_profile_overall") val riskProfileOverall: String? = null,
    @SerializedName("review_frequency") val reviewFrequency: String? = null,
    @SerializedName("notify_on_drift") val notifyOnDrift: Boolean? = null,
    @SerializedName("auto_adjust_on_income_change") val autoAdjustOnIncomeChange: Boolean? = null
)

// MARK: - Selected Goal

data class SelectedGoal(
    @SerializedName("goal_category") val goalCategory: String,
    @SerializedName("goal_name") val goalName: String,
    @SerializedName("estimated_cost") var estimatedCost: Double = 0.0,
    @SerializedName("target_date") var targetDate: String? = null,
    @SerializedName("current_savings") var currentSavings: Double = 0.0,
    @SerializedName("importance") var importance: Int = 3,
    @SerializedName("notes") var notes: String? = null
)

// MARK: - Goal Progress

data class GoalProgress(
    @SerializedName("goal_id") val goalId: String,
    @SerializedName("goal_name") val goalName: String,
    @SerializedName("progress_pct") val progressPct: Double,
    @SerializedName("current_savings_close") val currentSavingsClose: Double,
    @SerializedName("remaining_amount") val remainingAmount: Double,
    @SerializedName("projected_completion_date") val projectedCompletionDate: String?,
    @SerializedName("milestones") val milestones: List<Int>
)

data class GoalsProgressResponse(
    @SerializedName("goals") val goals: List<GoalProgress>
)

// MARK: - Submit Request/Response

data class GoalsSubmitRequest(
    @SerializedName("context") val context: LifeContext,
    @SerializedName("selected_goals") val selectedGoals: List<SelectedGoal>
)

data class GoalsSubmitResponse(
    @SerializedName("goals_created") val goalsCreated: List<GoalCreatedItem>
)

data class GoalCreatedItem(
    @SerializedName("goal_id") val goalId: String,
    @SerializedName("priority_rank") val priorityRank: Int?
)

// MARK: - Catalog Response

data class GoalCatalogResponse(
    @SerializedName("goals") val goals: List<GoalCatalogItem>
)

// MARK: - Life Context Response

data class LifeContextResponse(
    @SerializedName("context") val context: LifeContext?
)
