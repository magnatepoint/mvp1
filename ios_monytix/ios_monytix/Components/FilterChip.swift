//
//  FilterChip.swift
//  ios_monytix
//
//  Created by santosh on 12/01/26.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Theme.gold : Theme.darkGray)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Theme.gold : Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack {
            FilterChip(title: "All", isSelected: true, action: {})
            FilterChip(title: "Short Term", isSelected: false, action: {})
        }
    }
}
