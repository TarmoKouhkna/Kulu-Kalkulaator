//
//  LoanCalculatorView.swift
//  KutuseKalkulaator
//
//  Loan calculator - monthly payment, total interest, total cost.
//

import SwiftUI

enum DownpaymentMode: String, CaseIterable {
    case percent = "Protsent"
    case sum = "Summa"
}

struct LoanCalculatorView: View {
    @State private var loanAmount: String = ""
    @State private var annualInterestRate: String = ""
    @State private var loanTermYears: String = ""
    @State private var downpaymentMode: DownpaymentMode = .percent
    @State private var downpaymentValue: String = ""
    
    private var principal: Double {
        Double(loanAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var downpaymentAmount: Double {
        let value = Double(downpaymentValue.replacingOccurrences(of: ",", with: ".")) ?? 0
        switch downpaymentMode {
        case .percent: return principal * (value / 100)
        case .sum: return min(value, principal)
        }
    }
    
    /// Principal after downpayment (amount actually financed)
    private var effectivePrincipal: Double {
        max(0, principal - downpaymentAmount)
    }
    
    private var ratePercent: Double {
        Double(annualInterestRate.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var termYears: Double {
        Double(loanTermYears.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var numberOfMonths: Int {
        max(0, Int(termYears * 12))
    }
    
    private var monthlyRate: Double {
        (ratePercent / 100) / 12
    }
    
    /// Monthly payment using amortization formula: M = P * [r(1+r)^n] / [(1+r)^n - 1]
    private var monthlyPayment: Double? {
        guard effectivePrincipal > 0, numberOfMonths > 0 else { return nil }
        if monthlyRate == 0 {
            return effectivePrincipal / Double(numberOfMonths)
        }
        let r = monthlyRate
        let n = Double(numberOfMonths)
        let factor = pow(1 + r, n)
        return effectivePrincipal * (r * factor) / (factor - 1)
    }
    
    private var totalPaid: Double? {
        guard let monthly = monthlyPayment else { return nil }
        return monthly * Double(numberOfMonths)
    }
    
    private var totalInterest: Double? {
        guard let total = totalPaid else { return nil }
        return total - effectivePrincipal
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                CardContainer(title: "Laenu kalkulaator", icon: "banknote") {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledField(
                            label: "Laenu summa (€)",
                            text: $loanAmount,
                            placeholder: "10000"
                        )
                        
                        Picker("Sissemakse", selection: $downpaymentMode) {
                            ForEach(DownpaymentMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        LabeledField(
                            label: downpaymentMode == .percent ? "Sissemakse (%)" : "Sissemakse (€)",
                            text: $downpaymentValue,
                            placeholder: downpaymentMode == .percent ? "20" : "2000"
                        )
                        
                        LabeledField(
                            label: "Aastane intressimäär (%)",
                            text: $annualInterestRate,
                            placeholder: "5,5"
                        )
                        LabeledField(
                            label: "Laenuperiood (aastat)",
                            text: $loanTermYears,
                            placeholder: "5"
                        )
                    }
                }
                
                CardContainer(title: "Tulemused", icon: "eurosign.circle") {
                    VStack(spacing: 12) {
                        if downpaymentAmount > 0 {
                            ResultRow(
                                title: "Sissemakse",
                                value: String(format: "%.2f €", downpaymentAmount),
                                subtitle: nil
                            )
                        }
                        ResultRow(
                            title: "Kuumakse",
                            value: monthlyPayment.map { String(format: "%.2f €", $0) },
                            subtitle: nil
                        )
                        ResultRow(
                            title: "Kokku makstud",
                            value: totalPaid.map { String(format: "%.2f €", $0) },
                            subtitle: nil
                        )
                        ResultRow(
                            title: "Kokku intress",
                            value: totalInterest.map { String(format: "%.2f €", $0) },
                            subtitle: nil
                        )
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 600)
        }
        .frame(minWidth: 620, minHeight: 400)
        .background(Color("AppBackground"))
    }
}

#Preview {
    LoanCalculatorView()
        .frame(width: 520, height: 400)
}
