//
//  MoneyMomentsModels.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import Foundation
import SwiftUI

// MARK: - MoneyMoment

struct MoneyMoment: Identifiable, Codable {
    let id: String // Using habit_id as identifier
    let userId: String
    let month: String
    let habitId: String
    let value: Double
    let label: String
    let insightText: String
    let confidence: Double
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case month
        case habitId = "habit_id"
        case value
        case label
        case insightText = "insight_text"
        case confidence
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        month = try container.decode(String.self, forKey: .month)
        habitId = try container.decode(String.self, forKey: .habitId)
        value = try container.decode(Double.self, forKey: .value)
        label = try container.decode(String.self, forKey: .label)
        insightText = try container.decode(String.self, forKey: .insightText)
        confidence = try container.decode(Double.self, forKey: .confidence)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        id = habitId // Use habit_id as unique identifier
    }
    
    // Public initializer for preview/testing
    init(
        id: String,
        userId: String,
        month: String,
        habitId: String,
        value: Double,
        label: String,
        insightText: String,
        confidence: Double,
        createdAt: String
    ) {
        self.id = id
        self.userId = userId
        self.month = month
        self.habitId = habitId
        self.value = value
        self.label = label
        self.insightText = insightText
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

// MARK: - Nudge

struct Nudge: Identifiable, Codable {
    let id: String // Using delivery_id as identifier
    let deliveryId: String
    let userId: String
    let ruleId: String
    let templateCode: String
    let channel: String
    let sentAt: String
    let sendStatus: String
    let metadataJson: [String: Any]
    let titleTemplate: String?
    let bodyTemplate: String?
    let title: String?
    let body: String?
    let ctaText: String?
    let ctaDeeplink: String?
    let ruleName: String
    
    enum CodingKeys: String, CodingKey {
        case deliveryId = "delivery_id"
        case userId = "user_id"
        case ruleId = "rule_id"
        case templateCode = "template_code"
        case channel
        case sentAt = "sent_at"
        case sendStatus = "send_status"
        case metadataJson = "metadata_json"
        case titleTemplate = "title_template"
        case bodyTemplate = "body_template"
        case title
        case body
        case ctaText = "cta_text"
        case ctaDeeplink = "cta_deeplink"
        case ruleName = "rule_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deliveryId = try container.decode(String.self, forKey: .deliveryId)
        userId = try container.decode(String.self, forKey: .userId)
        ruleId = try container.decode(String.self, forKey: .ruleId)
        templateCode = try container.decode(String.self, forKey: .templateCode)
        channel = try container.decode(String.self, forKey: .channel)
        sentAt = try container.decode(String.self, forKey: .sentAt)
        sendStatus = try container.decode(String.self, forKey: .sendStatus)
        
        // Decode metadata_json as [String: Any]
        if let metadataData = try? container.decode([String: AnyCodable].self, forKey: .metadataJson) {
            metadataJson = metadataData.mapValues { $0.value }
        } else {
            metadataJson = [:]
        }
        
        titleTemplate = try container.decodeIfPresent(String.self, forKey: .titleTemplate)
        bodyTemplate = try container.decodeIfPresent(String.self, forKey: .bodyTemplate)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        ctaText = try container.decodeIfPresent(String.self, forKey: .ctaText)
        ctaDeeplink = try container.decodeIfPresent(String.self, forKey: .ctaDeeplink)
        ruleName = try container.decode(String.self, forKey: .ruleName)
        
        id = deliveryId // Use delivery_id as unique identifier
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deliveryId, forKey: .deliveryId)
        try container.encode(userId, forKey: .userId)
        try container.encode(ruleId, forKey: .ruleId)
        try container.encode(templateCode, forKey: .templateCode)
        try container.encode(channel, forKey: .channel)
        try container.encode(sentAt, forKey: .sentAt)
        try container.encode(sendStatus, forKey: .sendStatus)
        
        // Encode metadata_json using AnyCodable
        let metadataCodable = metadataJson.mapValues { AnyCodable($0) }
        try container.encode(metadataCodable, forKey: .metadataJson)
        
        try container.encodeIfPresent(titleTemplate, forKey: .titleTemplate)
        try container.encodeIfPresent(bodyTemplate, forKey: .bodyTemplate)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(ctaText, forKey: .ctaText)
        try container.encodeIfPresent(ctaDeeplink, forKey: .ctaDeeplink)
        try container.encode(ruleName, forKey: .ruleName)
    }
    
    // Public initializer for preview/testing
    init(
        id: String,
        deliveryId: String,
        userId: String,
        ruleId: String,
        templateCode: String,
        channel: String,
        sentAt: String,
        sendStatus: String,
        metadataJson: [String: Any],
        titleTemplate: String?,
        bodyTemplate: String?,
        title: String?,
        body: String?,
        ctaText: String?,
        ctaDeeplink: String?,
        ruleName: String
    ) {
        self.id = id
        self.deliveryId = deliveryId
        self.userId = userId
        self.ruleId = ruleId
        self.templateCode = templateCode
        self.channel = channel
        self.sentAt = sentAt
        self.sendStatus = sendStatus
        self.metadataJson = metadataJson
        self.titleTemplate = titleTemplate
        self.bodyTemplate = bodyTemplate
        self.title = title
        self.body = body
        self.ctaText = ctaText
        self.ctaDeeplink = ctaDeeplink
        self.ruleName = ruleName
    }
}

// MARK: - Helper for decoding [String: Any]

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

// MARK: - API Response Models

struct MoneyMomentsResponse: Codable {
    let moments: [MoneyMoment]
}

struct ComputeMomentsResponse: Codable {
    let status: String
    let moments: [MoneyMoment]
    let count: Int
    let message: String?
}

struct NudgesResponse: Codable {
    let nudges: [Nudge]
}

struct EvaluateNudgesResponse: Codable {
    let status: String
    let count: Int
    let candidates: [String]? // Optional array of candidate IDs
}

struct ProcessNudgesResponse: Codable {
    let status: String
    let delivered: [Nudge]
    let count: Int
}

struct ComputeSignalResponse: Codable {
    let status: String
    let signal: [String: AnyCodable]? // Signal data as dictionary
    
    enum CodingKeys: String, CodingKey {
        case status
        case signal
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(String.self, forKey: .status)
        
        if let signalData = try? container.decode([String: AnyCodable].self, forKey: .signal) {
            signal = signalData
        } else {
            signal = nil
        }
    }
}

struct NudgeInteractionResponse: Codable {
    let status: String
}

// MARK: - Habit

struct Habit: Identifiable {
    let id: String // Using habit_id as identifier
    let habitId: String
    let name: String
    let description: String
    let priority: HabitPriority
    let frequency: HabitFrequency
    let currentStreak: Int
    let targetStreak: Int
    let icon: String
    let createdAt: Date?
    
    var progressPercentage: Double {
        guard targetStreak > 0 else { return 0 }
        return min(1.0, Double(currentStreak) / Double(targetStreak))
    }
    
    var displayProgress: String {
        return "\(currentStreak)/\(targetStreak)"
    }
}

enum HabitPriority: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
}

enum HabitFrequency: String {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
}

// MARK: - Progress Metrics

struct ProgressMetrics {
    let streak: Int
    let nudgesCount: Int
    let habitsCount: Int
    let savedAmount: Double
    
    static let empty = ProgressMetrics(streak: 0, nudgesCount: 0, habitsCount: 0, savedAmount: 0)
}

// MARK: - AI Insight

struct MoneyMomentsAIInsight: Identifiable {
    let id: String
    let type: MoneyMomentsInsightType
    let message: String
    let timestamp: Date
    let icon: String
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum MoneyMomentsInsightType: String {
    case progress = "Great Progress!"
    case suggestion = "Habit Suggestion"
    case milestone = "Milestone Reached"
    
    var icon: String {
        switch self {
        case .progress: return "trophy.fill"
        case .suggestion: return "lightbulb.fill"
        case .milestone: return "leaf.fill"
        }
    }
}

