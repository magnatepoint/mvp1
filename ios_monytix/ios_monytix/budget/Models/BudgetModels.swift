//
//  BudgetModels.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation

// MARK: - Budget Recommendation

struct BudgetRecommendation: Codable, Identifiable {
    let planCode: String
    let name: String
    let description: String?
    let needsBudgetPct: Double
    let wantsBudgetPct: Double
    let savingsBudgetPct: Double
    let score: Double
    let recommendationReason: String
    let goalPreview: [GoalAllocationPreview]?
    
    var id: String { planCode }
    
    enum CodingKeys: String, CodingKey {
        case planCode = "plan_code"
        case name
        case description
        case needsBudgetPct = "needs_budget_pct"
        case wantsBudgetPct = "wants_budget_pct"
        case savingsBudgetPct = "savings_budget_pct"
        case score
        case recommendationReason = "recommendation_reason"
        case goalPreview = "goal_preview"
    }
}

struct GoalAllocationPreview: Codable, Identifiable {
    let goalId: String
    let goalName: String
    let allocationPct: Double
    let allocationAmount: Double
    
    var id: String { goalId }
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case goalName = "goal_name"
        case allocationPct = "allocation_pct"
        case allocationAmount = "allocation_amount"
    }
}

// MARK: - Budget Commit

struct BudgetCommitRequest: Codable {
    let planCode: String
    let month: String?
    let goalAllocations: [String: Double]?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case planCode = "plan_code"
        case month
        case goalAllocations = "goal_allocations"
        case notes
    }
}

struct GoalAllocation: Codable, Identifiable {
    let ubcgaId: String
    let userId: String
    let month: String
    let goalId: String
    let goalName: String?
    let weightPct: Double
    let plannedAmount: Double
    let createdAt: String
    
    var id: String { ubcgaId }
    
    enum CodingKeys: String, CodingKey {
        case ubcgaId = "ubcga_id"
        case userId = "user_id"
        case month
        case goalId = "goal_id"
        case goalName = "goal_name"
        case weightPct = "weight_pct"
        case plannedAmount = "planned_amount"
        case createdAt = "created_at"
    }
}

struct CommittedBudget: Codable {
    let userId: String
    let month: String
    let planCode: String
    let allocNeedsPct: Double
    let allocWantsPct: Double
    let allocAssetsPct: Double
    let notes: String?
    let committedAt: String
    let goalAllocations: [GoalAllocation]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case month
        case planCode = "plan_code"
        case allocNeedsPct = "alloc_needs_pct"
        case allocWantsPct = "alloc_wants_pct"
        case allocAssetsPct = "alloc_assets_pct"
        case notes
        case committedAt = "committed_at"
        case goalAllocations = "goal_allocations"
    }
}

// MARK: - Budget Variance

struct BudgetVariance: Codable {
    let userId: String
    let month: String
    let incomeAmt: Double
    let needsAmt: Double
    let plannedNeedsAmt: Double
    let varianceNeedsAmt: Double
    let wantsAmt: Double
    let plannedWantsAmt: Double
    let varianceWantsAmt: Double
    let assetsAmt: Double
    let plannedAssetsAmt: Double
    let varianceAssetsAmt: Double
    let computedAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case month
        case incomeAmt = "income_amt"
        case needsAmt = "needs_amt"
        case plannedNeedsAmt = "planned_needs_amt"
        case varianceNeedsAmt = "variance_needs_amt"
        case wantsAmt = "wants_amt"
        case plannedWantsAmt = "planned_wants_amt"
        case varianceWantsAmt = "variance_wants_amt"
        case assetsAmt = "assets_amt"
        case plannedAssetsAmt = "planned_assets_amt"
        case varianceAssetsAmt = "variance_assets_amt"
        case computedAt = "computed_at"
    }
}

// MARK: - API Responses

struct BudgetRecommendationsResponse: Codable {
    let recommendations: [BudgetRecommendation]
}

struct BudgetCommitResponse: Codable {
    let status: String
    let budget: CommittedBudget
}

struct CommittedBudgetResponse: Codable {
    let status: String
    let budget: CommittedBudget?
}

struct BudgetVarianceResponse: Codable {
    let status: String
    let aggregate: BudgetVariance?
}

