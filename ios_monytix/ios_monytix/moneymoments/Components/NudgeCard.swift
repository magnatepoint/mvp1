//
//  NudgeCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct NudgeCard: View {
    let nudge: Nudge
    let onInteraction: (String, String) -> Void // (deliveryId, eventType)
    
    @State private var hasTrackedView = false
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216) // #D4AF37
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                // Header with rule name and date
                HStack {
                    // Sparkles icon
                    Image(systemName: "sparkles")
                        .foregroundColor(goldColor)
                        .font(.system(size: 16))
                    
                    // Rule name
                    Text(nudge.ruleName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.8))
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    // Sent date
                    Text(formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                }
                
                // Title
                Text(nudge.title ?? nudge.titleTemplate ?? "Nudge")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                // Body
                if let body = nudge.body ?? nudge.bodyTemplate, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.9))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // CTA Button
                if let ctaText = nudge.ctaText, !ctaText.isEmpty {
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        onInteraction(nudge.deliveryId, "click")
                    }) {
                        Text(ctaText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(goldColor)
                            )
                    }
                }
            }
        }
        .onAppear {
            // Track view when card appears
            if !hasTrackedView {
                hasTrackedView = true
                onInteraction(nudge.deliveryId, "view")
            }
        }
    }
    
    // MARK: - Formatted Date
    
    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: nudge.sentAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        } else {
            // Fallback: try without fractional seconds
            let fallbackFormatter = ISO8601DateFormatter()
            if let date = fallbackFormatter.date(from: nudge.sentAt) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .medium
                displayFormatter.timeStyle = .none
                return displayFormatter.string(from: date)
            }
        }
        
        return nudge.sentAt
    }
}

#Preview {
    VStack(spacing: 16) {
        NudgeCard(
            nudge: Nudge(
                id: "test1",
                deliveryId: "delivery123",
                userId: "user123",
                ruleId: "rule1",
                templateCode: "template1",
                channel: "app",
                sentAt: "2025-01-15T10:00:00Z",
                sendStatus: "sent",
                metadataJson: [:],
                titleTemplate: "Save More This Month",
                bodyTemplate: "You're spending more than usual on dining. Consider cooking at home more often.",
                title: "Save More This Month",
                body: "You're spending more than usual on dining. Consider cooking at home more often.",
                ctaText: "View Budget",
                ctaDeeplink: "budget://view",
                ruleName: "High Dining Spending"
            ),
            onInteraction: { deliveryId, eventType in
                print("Interaction: \(eventType) for \(deliveryId)")
            }
        )
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

