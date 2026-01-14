//
//  WantsGaugeView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct WantsGaugeView: View {
    let gauge: WantsGauge
    
    @State private var animatedRatio: Double = 0
    @State private var isVisible = false
    
    private var percentage: Int {
        Int(animatedRatio * 100)
    }
    
    private var gaugeColor: Color {
        gauge.thresholdCrossed ? Color(red: 0.957, green: 0.263, blue: 0.212) : Color(red: 1.0, green: 0.596, blue: 0.0)
    }
    
    var body: some View {
        GlassCard(padding: 20, cornerRadius: 16) {
            VStack(spacing: 20) {
                Text("Wants vs Needs")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Circular gauge
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(
                            Color.gray.opacity(0.2),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: animatedRatio)
                        .stroke(
                            gaugeColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.7), value: animatedRatio)
                    
                    // Center content
                    VStack(spacing: 4) {
                        Text("\(percentage)%")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        
                        Text("Wants")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
                
                // Label
                Text(gauge.label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                isVisible = true
            }
            
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7).delay(0.4)) {
                animatedRatio = gauge.ratio
            }
        }
        .onChange(of: gauge.ratio) { oldValue, newValue in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedRatio = newValue
            }
        }
    }
}

#Preview {
    WantsGaugeView(
        gauge: WantsGauge(
            ratio: 0.35,
            thresholdCrossed: false,
            label: "Chill Mode"
        )
    )
    .padding()
    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

