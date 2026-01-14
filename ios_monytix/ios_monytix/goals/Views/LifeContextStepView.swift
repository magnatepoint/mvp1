//
//  LifeContextStepView.swift
//  ios_monytix
//
//  Created by santosh on 05/01/26.
//

import SwiftUI

struct LifeContextStepView: View {
    @ObservedObject var viewModel: GoalsViewModel
    
    @State private var ageBand: String = ""
    @State private var dependentsSpouse: Bool = false
    @State private var dependentsChildrenCount: Int = 0
    @State private var dependentsParentsCare: Bool = false
    @State private var housing: String = ""
    @State private var employment: String = ""
    @State private var incomeRegularity: String = ""
    @State private var regionCode: String = ""
    @State private var emergencyOptOut: Bool = false
    @State private var riskProfile: String = ""
    @State private var reviewFrequency: String = "quarterly"
    
    @State private var errors: [String: String] = [:]
    
    private let goldColor = Color(red: 0.831, green: 0.686, blue: 0.216)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tell Us About Yourself")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("This helps us recommend the right goals for you.")
                        .font(.system(size: 15))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 20) {
                    // Age Band
                    FormField(
                        title: "Age Range *",
                        error: errors["age_band"]
                    ) {
                        Picker("Age Range", selection: $ageBand) {
                            Text("Select age range").tag("")
                            Text("18-24").tag("18-24")
                            Text("25-34").tag("25-34")
                            Text("35-44").tag("35-44")
                            Text("45-54").tag("45-54")
                            Text("55+").tag("55+")
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                    }
                    
                    // Housing
                    FormField(
                        title: "Housing Status *",
                        error: errors["housing"]
                    ) {
                        Picker("Housing", selection: $housing) {
                            Text("Select housing status").tag("")
                            Text("Rent").tag("rent")
                            Text("Own with Mortgage").tag("own_mortgage")
                            Text("Own without Mortgage").tag("own_nomortgage")
                            Text("Living with Parents").tag("living_with_parents")
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                    }
                    
                    // Employment
                    FormField(
                        title: "Employment Type *",
                        error: errors["employment"]
                    ) {
                        Picker("Employment", selection: $employment) {
                            Text("Select employment type").tag("")
                            Text("Salaried").tag("salaried")
                            Text("Self Employed").tag("self_employed")
                            Text("Student").tag("student")
                            Text("Homemaker").tag("homemaker")
                            Text("Retired").tag("retired")
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                    }
                    
                    // Income Regularity
                    FormField(
                        title: "Income Regularity *",
                        error: errors["income_regularity"]
                    ) {
                        Picker("Income Regularity", selection: $incomeRegularity) {
                            Text("Select income regularity").tag("")
                            Text("Very Stable").tag("very_stable")
                            Text("Stable").tag("stable")
                            Text("Variable").tag("variable")
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                    }
                    
                    // Region
                    FormField(
                        title: "Region *",
                        error: errors["region_code"]
                    ) {
                        Picker("Region", selection: $regionCode) {
                            Text("Select region").tag("")
                            ForEach(IndianState.allStates, id: \.self) { code in
                                Text(IndianState.displayName(for: code)).tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                    }
                    
                    // Dependents
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dependents")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Toggle("Has Spouse/Partner", isOn: $dependentsSpouse)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text("Number of Children")
                            Spacer()
                            Stepper("\(dependentsChildrenCount)", value: $dependentsChildrenCount, in: 0...10)
                                .foregroundColor(.white)
                        }
                        
                        Toggle("Caring for Parents", isOn: $dependentsParentsCare)
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Risk Profile
                    FormField(
                        title: "Risk Profile",
                        error: nil
                    ) {
                        Picker("Risk Profile", selection: $riskProfile) {
                            Text("Select risk profile").tag("")
                            Text("Conservative").tag("conservative")
                            Text("Balanced").tag("balanced")
                            Text("Aggressive").tag("aggressive")
                        }
                        .pickerStyle(.menu)
                        .foregroundColor(.white)
                    }
                    
                    // Review Frequency
                    FormField(
                        title: "Review Frequency",
                        error: nil
                    ) {
                        Picker("Review Frequency", selection: $reviewFrequency) {
                            Text("Monthly").tag("monthly")
                            Text("Quarterly").tag("quarterly")
                            Text("Yearly").tag("yearly")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 20)
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    Spacer()
                    
                    Button(action: {
                        if validate() {
                            saveLifeContext()
                            viewModel.nextStep()
                        }
                    }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(goldColor)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            loadExistingContext()
        }
    }
    
    private func loadExistingContext() {
        if let context = viewModel.lifeContext {
            ageBand = context.ageBand
            dependentsSpouse = context.dependentsSpouse
            dependentsChildrenCount = context.dependentsChildrenCount
            dependentsParentsCare = context.dependentsParentsCare
            housing = context.housing
            employment = context.employment
            incomeRegularity = context.incomeRegularity
            regionCode = context.regionCode
            emergencyOptOut = context.emergencyOptOut
            riskProfile = context.riskProfileOverall ?? ""
            reviewFrequency = context.reviewFrequency ?? "quarterly"
        }
    }
    
    private func validate() -> Bool {
        errors = [:]
        
        if ageBand.isEmpty {
            errors["age_band"] = "Age range is required"
        }
        if housing.isEmpty {
            errors["housing"] = "Housing status is required"
        }
        if employment.isEmpty {
            errors["employment"] = "Employment type is required"
        }
        if incomeRegularity.isEmpty {
            errors["income_regularity"] = "Income regularity is required"
        }
        if regionCode.isEmpty {
            errors["region_code"] = "Region is required"
        }
        
        return errors.isEmpty
    }
    
    private func saveLifeContext() {
        let context = LifeContext(
            ageBand: ageBand,
            dependentsSpouse: dependentsSpouse,
            dependentsChildrenCount: dependentsChildrenCount,
            dependentsParentsCare: dependentsParentsCare,
            housing: housing,
            employment: employment,
            incomeRegularity: incomeRegularity,
            regionCode: regionCode,
            emergencyOptOut: emergencyOptOut,
            monthlyInvestibleCapacity: nil,
            totalMonthlyEMIObligations: nil,
            riskProfileOverall: riskProfile.isEmpty ? nil : riskProfile,
            reviewFrequency: reviewFrequency,
            notifyOnDrift: true,
            autoAdjustOnIncomeChange: false
        )
        
        Task {
            await viewModel.updateLifeContext(context)
        }
    }
}

// MARK: - Form Field

struct FormField<Content: View>: View {
    let title: String
    let error: String?
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray.opacity(0.7))
            
            content()
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            if let error = error {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    LifeContextStepView(viewModel: GoalsViewModel(authService: AuthService()))
        .background(Color(red: 0.18, green: 0.18, blue: 0.18))
}

