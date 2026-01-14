//
//  GlassCard.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    private let goldColor = Theme.gold
    private let darkCharcoalColor = Theme.charcoal
    
    init(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(darkCharcoalColor.opacity(0.6))
                    .background {
                        // Glass morphism effect
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                .ultraThinMaterial
                            )
                            .opacity(0.3)
                    }
                    .overlay {
                        // Gold border
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        goldColor.opacity(0.3),
                                        goldColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
            }
    }
}

// Convenience extension for margins
extension GlassCard {
    func margin(_ edges: Edge.Set = .all, _ length: CGFloat = 16) -> some View {
        self.padding(edges, length)
    }
}

#Preview {
    GlassCard {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glass Card")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("This is a glass morphism card with blur effect and gold border")
                .font(.body)
                .foregroundColor(.gray)
        }
    }
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

