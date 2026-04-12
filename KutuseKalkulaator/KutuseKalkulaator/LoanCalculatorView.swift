//
//  LoanCalculatorView.swift
//  KutuseKalkulaator
//
//  Loan calculator - monthly payment, total interest, total cost, year-by-year amortization schedule.
//

import SwiftUI

enum DownpaymentMode: String, CaseIterable {
    case percent = "Protsent"
    case sum = "Summa"
}

private struct AmortizationYear: Identifiable {
    let id = UUID()
    let year: Int
    let principalPaid: Double
    let interestPaid: Double
    let remainingBalance: Double
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

    private var amortizationSchedule: [AmortizationYear] {
        guard let monthly = monthlyPayment, effectivePrincipal > 0, numberOfMonths > 0 else { return [] }
        var rows: [AmortizationYear] = []
        var balance = effectivePrincipal
        let r = monthlyRate
        let totalYears = Int(ceil(termYears))
        guard totalYears > 0 else { return [] }

        for year in 1...totalYears {
            let startMonth = (year - 1) * 12 + 1
            let endMonth = min(year * 12, numberOfMonths)
            if startMonth > numberOfMonths { break }

            var yearPrincipal = 0.0
            var yearInterest  = 0.0

            for _ in startMonth...endMonth {
                let interest  = r == 0 ? 0 : balance * r
                let payment   = r == 0 ? effectivePrincipal / Double(numberOfMonths) : monthly
                let principal = min(payment - interest, balance)
                yearInterest  += interest
                yearPrincipal += principal
                balance        = max(0, balance - principal)
            }

            rows.append(AmortizationYear(
                year: year,
                principalPaid: yearPrincipal,
                interestPaid: yearInterest,
                remainingBalance: balance
            ))
        }
        return rows
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
                                value: fmtNum(downpaymentAmount, decimals: 2, suffix: "€"),
                                subtitle: nil
                            )
                        }
                        ResultRow(
                            title: "Kuumakse",
                            value: monthlyPayment.map { fmtNum($0, decimals: 2, suffix: "€") },
                            subtitle: nil
                        )
                        ResultRow(
                            title: "Kokku makstud",
                            value: totalPaid.map { fmtNum($0, decimals: 2, suffix: "€") },
                            subtitle: nil
                        )
                        ResultRow(
                            title: "Kokku intress",
                            value: totalInterest.map { fmtNum($0, decimals: 2, suffix: "€") },
                            subtitle: nil
                        )
                    }
                }

                // Amortization schedule
                let schedule = amortizationSchedule
                if !schedule.isEmpty {
                    CardContainer(title: "Tagasimaksegraafik (aasta kaupa)", icon: "calendar") {
                        VStack(spacing: 0) {
                            // Header
                            HStack(spacing: 8) {
                                Text("Aasta")
                                    .frame(width: 46, alignment: .leading)
                                Text("Põhiosa")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("Intress")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("Jääk")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 6)

                            Divider()

                            ForEach(schedule.indices, id: \.self) { idx in
                                let row = schedule[idx]
                                HStack(spacing: 8) {
                                    Text("\(row.year)")
                                        .frame(width: 46, alignment: .leading)
                                        .foregroundStyle(.secondary)
                                    Text(fmtNum(row.principalPaid, decimals: 0, suffix: "€"))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .monospacedDigit()
                                    Text(fmtNum(row.interestPaid, decimals: 0, suffix: "€"))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .monospacedDigit()
                                        .foregroundStyle(.orange)
                                    Text(fmtNum(row.remainingBalance, decimals: 0, suffix: "€"))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                                .padding(.vertical, 5)

                                if idx < schedule.count - 1 {
                                    Divider().opacity(0.4)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 600)
        }
        .frame(minWidth: 620, minHeight: 400)
        .background(
            LinearGradient(
                colors: [Color("AppBackground"), Color(red: 0.76, green: 0.85, blue: 0.79)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

#Preview {
    LoanCalculatorView()
        .frame(width: 520, height: 600)
}
