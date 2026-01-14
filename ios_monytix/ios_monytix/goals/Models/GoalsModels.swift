//
//  GoalsModels.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation

// MARK: - Goal Catalog

struct GoalCatalogItem: Codable, Identifiable {
    let id = UUID()
    let goalCategory: String
    let goalName: String
    let defaultHorizon: String
    let policyLinkedTxnType: String
    let isMandatoryFlag: Bool
    let suggestedMinAmountFormula: String?
    let displayOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case goalCategory = "goal_category"
        case goalName = "goal_name"
        case defaultHorizon = "default_horizon"
        case policyLinkedTxnType = "policy_linked_txn_type"
        case isMandatoryFlag = "is_mandatory_flag"
        case suggestedMinAmountFormula = "suggested_min_amount_formula"
        case displayOrder = "display_order"
    }
}

enum GoalHorizon: String, Codable {
    case shortTerm = "short_term"
    case mediumTerm = "medium_term"
    case longTerm = "long_term"
    
    var displayName: String {
        switch self {
        case .shortTerm:
            return "Short Term (0-2 years)"
        case .mediumTerm:
            return "Medium Term (2-5 years)"
        case .longTerm:
            return "Long Term (5+ years)"
        }
    }
}

// MARK: - Life Context

struct LifeContext: Codable {
    let ageBand: String
    let dependentsSpouse: Bool
    let dependentsChildrenCount: Int
    let dependentsParentsCare: Bool
    let housing: String
    let employment: String
    let incomeRegularity: String
    let regionCode: String
    let emergencyOptOut: Bool
    let monthlyInvestibleCapacity: Double?
    let totalMonthlyEMIObligations: Double?
    let riskProfileOverall: String?
    let reviewFrequency: String?
    let notifyOnDrift: Bool?
    let autoAdjustOnIncomeChange: Bool?
    
    enum CodingKeys: String, CodingKey {
        case ageBand = "age_band"
        case dependentsSpouse = "dependents_spouse"
        case dependentsChildrenCount = "dependents_children_count"
        case dependentsParentsCare = "dependents_parents_care"
        case housing
        case employment
        case incomeRegularity = "income_regularity"
        case regionCode = "region_code"
        case emergencyOptOut = "emergency_opt_out"
        case monthlyInvestibleCapacity = "monthly_investible_capacity"
        case totalMonthlyEMIObligations = "total_monthly_emi_obligations"
        case riskProfileOverall = "risk_profile_overall"
        case reviewFrequency = "review_frequency"
        case notifyOnDrift = "notify_on_drift"
        case autoAdjustOnIncomeChange = "auto_adjust_on_income_change"
    }
}

// MARK: - Selected Goal

struct SelectedGoal: Codable, Identifiable {
    let id = UUID()
    let goalCategory: String
    let goalName: String
    var estimatedCost: Double
    var targetDate: Date?
    var currentSavings: Double
    var importance: Int
    var notes: String?
    
    enum CodingKeys: String, CodingKey {
        case goalCategory = "goal_category"
        case goalName = "goal_name"
        case estimatedCost = "estimated_cost"
        case targetDate = "target_date"
        case currentSavings = "current_savings"
        case importance
        case notes
    }
    
    init(goalCategory: String, goalName: String, estimatedCost: Double = 0, targetDate: Date? = nil, currentSavings: Double = 0, importance: Int = 3, notes: String? = nil) {
        self.goalCategory = goalCategory
        self.goalName = goalName
        self.estimatedCost = estimatedCost
        self.targetDate = targetDate
        self.currentSavings = currentSavings
        self.importance = importance
        self.notes = notes
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalCategory = try container.decode(String.self, forKey: .goalCategory)
        goalName = try container.decode(String.self, forKey: .goalName)
        estimatedCost = try container.decode(Double.self, forKey: .estimatedCost)
        currentSavings = try container.decode(Double.self, forKey: .currentSavings)
        importance = try container.decode(Int.self, forKey: .importance)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .targetDate) {
            let formatter = ISO8601DateFormatter()
            targetDate = formatter.date(from: dateString)
        } else {
            targetDate = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(goalCategory, forKey: .goalCategory)
        try container.encode(goalName, forKey: .goalName)
        try container.encode(estimatedCost, forKey: .estimatedCost)
        try container.encode(currentSavings, forKey: .currentSavings)
        try container.encode(importance, forKey: .importance)
        try container.encodeIfPresent(notes, forKey: .notes)
        
        if let targetDate = targetDate {
            // Backend expects date in YYYY-MM-DD format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            try container.encode(formatter.string(from: targetDate), forKey: .targetDate)
        } else {
            try container.encodeNil(forKey: .targetDate)
        }
    }
}

// MARK: - Goal Response

struct GoalResponse: Codable, Identifiable {
    let goalId: UUID
    let goalCategory: String
    let goalName: String
    let goalType: String
    let linkedTxnType: String?
    let estimatedCost: Double
    let targetDate: Date?
    let currentSavings: Double
    let importance: Int?
    let priorityRank: Int?
    let status: String
    let notes: String?
    let createdAt: String
    let updatedAt: String
    
    var id: UUID { goalId }
    
    // Public initializer for creating instances
    init(
        goalId: UUID,
        goalCategory: String,
        goalName: String,
        goalType: String,
        linkedTxnType: String?,
        estimatedCost: Double,
        targetDate: Date?,
        currentSavings: Double,
        importance: Int?,
        priorityRank: Int?,
        status: String,
        notes: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.goalId = goalId
        self.goalCategory = goalCategory
        self.goalName = goalName
        self.goalType = goalType
        self.linkedTxnType = linkedTxnType
        self.estimatedCost = estimatedCost
        self.targetDate = targetDate
        self.currentSavings = currentSavings
        self.importance = importance
        self.priorityRank = priorityRank
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case goalCategory = "goal_category"
        case goalName = "goal_name"
        case goalType = "goal_type"
        case linkedTxnType = "linked_txn_type"
        case estimatedCost = "estimated_cost"
        case targetDate = "target_date"
        case currentSavings = "current_savings"
        case importance
        case priorityRank = "priority_rank"
        case status
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        goalId = try container.decode(UUID.self, forKey: .goalId)
        goalCategory = try container.decode(String.self, forKey: .goalCategory)
        goalName = try container.decode(String.self, forKey: .goalName)
        goalType = try container.decode(String.self, forKey: .goalType)
        linkedTxnType = try container.decodeIfPresent(String.self, forKey: .linkedTxnType)
        estimatedCost = try container.decode(Double.self, forKey: .estimatedCost)
        currentSavings = try container.decode(Double.self, forKey: .currentSavings)
        importance = try container.decodeIfPresent(Int.self, forKey: .importance)
        priorityRank = try container.decodeIfPresent(Int.self, forKey: .priorityRank)
        status = try container.decode(String.self, forKey: .status)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        
        if let dateString = try? container.decodeIfPresent(String.self, forKey: .targetDate) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            targetDate = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        } else {
            targetDate = nil
        }
    }
}

// MARK: - Goal Progress

struct GoalProgress: Codable, Identifiable {
    let goalId: String
    let goalName: String
    let progressPct: Double
    let currentSavingsClose: Double
    let remainingAmount: Double
    let projectedCompletionDate: String?
    let milestones: [Int]
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case goalName = "goal_name"
        case progressPct = "progress_pct"
        case currentSavingsClose = "current_savings_close"
        case remainingAmount = "remaining_amount"
        case projectedCompletionDate = "projected_completion_date"
        case milestones
    }
    
    var id: String { goalId }
}

struct GoalsProgressResponse: Codable {
    let goals: [GoalProgress]
}

// MARK: - Submit Request/Response

struct GoalsSubmitRequest: Codable {
    let context: LifeContext
    let selectedGoals: [SelectedGoal]
    
    enum CodingKeys: String, CodingKey {
        case context
        case selectedGoals = "selected_goals"
    }
}

struct GoalsSubmitResponse: Codable {
    let goalsCreated: [GoalCreatedItem]
    
    enum CodingKeys: String, CodingKey {
        case goalsCreated = "goals_created"
    }
}

struct GoalCreatedItem: Codable {
    let goalId: String
    let priorityRank: Int?
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case priorityRank = "priority_rank"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle goal_id as either UUID string or UUID object
        if let uuid = try? container.decode(UUID.self, forKey: .goalId) {
            goalId = uuid.uuidString
        } else if let string = try? container.decode(String.self, forKey: .goalId) {
            goalId = string
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "goal_id must be UUID or String"))
        }
        
        priorityRank = try container.decodeIfPresent(Int.self, forKey: .priorityRank)
    }
}

// MARK: - Indian States

struct IndianState {
    static let allStates = [
        "IN-AP", "IN-AR", "IN-AS", "IN-BR", "IN-CT", "IN-GA", "IN-GJ", "IN-HR",
        "IN-HP", "IN-JK", "IN-JH", "IN-KA", "IN-KL", "IN-MP", "IN-MH", "IN-MN",
        "IN-ML", "IN-MZ", "IN-NL", "IN-OR", "IN-PB", "IN-RJ", "IN-SK", "IN-TN",
        "IN-TG", "IN-TR", "IN-UP", "IN-UT", "IN-WB", "IN-AN", "IN-CH", "IN-DH",
        "IN-DL", "IN-LD", "IN-PY"
    ]
    
    static func displayName(for code: String) -> String {
        let stateNames: [String: String] = [
            "IN-AP": "Andhra Pradesh",
            "IN-AR": "Arunachal Pradesh",
            "IN-AS": "Assam",
            "IN-BR": "Bihar",
            "IN-CT": "Chhattisgarh",
            "IN-GA": "Goa",
            "IN-GJ": "Gujarat",
            "IN-HR": "Haryana",
            "IN-HP": "Himachal Pradesh",
            "IN-JK": "Jammu & Kashmir",
            "IN-JH": "Jharkhand",
            "IN-KA": "Karnataka",
            "IN-KL": "Kerala",
            "IN-MP": "Madhya Pradesh",
            "IN-MH": "Maharashtra",
            "IN-MN": "Manipur",
            "IN-ML": "Meghalaya",
            "IN-MZ": "Mizoram",
            "IN-NL": "Nagaland",
            "IN-OR": "Odisha",
            "IN-PB": "Punjab",
            "IN-RJ": "Rajasthan",
            "IN-SK": "Sikkim",
            "IN-TN": "Tamil Nadu",
            "IN-TG": "Telangana",
            "IN-TR": "Tripura",
            "IN-UP": "Uttar Pradesh",
            "IN-UT": "Uttarakhand",
            "IN-WB": "West Bengal",
            "IN-AN": "Andaman & Nicobar",
            "IN-CH": "Chandigarh",
            "IN-DH": "Dadra & Nagar Haveli",
            "IN-DL": "Delhi",
            "IN-LD": "Lakshadweep",
            "IN-PY": "Puducherry"
        ]
        return stateNames[code] ?? code
    }
}

// MARK: - Goal Status

enum GoalStatus: String, Codable {
    case active = "active"
    case completed = "completed"
    case archived = "archived"
}


