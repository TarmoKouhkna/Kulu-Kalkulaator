//
//  SalaryTaxView.swift
//  KutuseKalkulaator
//
//  Estonian salary tax calculator - 2026 rates (EMTA).
//

import SwiftUI
import AppKit

// MARK: - 2026 Estonian Tax Constants

private enum TaxRates2026 {
    static let socialTaxRate = 0.33
    static let incomeTaxRate = 0.22
    static let employerUnemploymentRate = 0.008
    static let employeeUnemploymentRate = 0.016
    static let minSocialTaxBasis: Double = 886
    static let defaultTaxFreeAmount: Double = 700
    static let pensionerTaxFreeAmount: Double = 776
}

enum SalaryInputMode: String, CaseIterable {
    case employerCost = "Tööandja kulu"
    case gross = "Brutopalk"
    case net = "Netopalk"
}

struct SalaryTaxView: View {
    // Input
    @State private var inputMode: SalaryInputMode = .gross
    @State private var inputAmount: String = ""
    @State private var taxFreeAmount: String = ""
    @State private var useTaxFreeCheckbox: Bool = true

    // Deductions (Mahaarvamised)
    @State private var useMinSocialTaxBasis: Bool = false
    @State private var useAutoTaxFree: Bool = true
    @State private var isPensioner: Bool = false
    @State private var includeEmployerUI: Bool = true
    @State private var includeEmployeeUI: Bool = true
    @State private var includePension: Bool = true
    @State private var pensionRate: Double = 2

    // Copy feedback
    @State private var copyConfirmed = false

    private var inputValue: Double {
        Double(inputAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var effectiveTaxFree: Double {
        guard useTaxFreeCheckbox else { return 0 }
        if useAutoTaxFree {
            return isPensioner ? TaxRates2026.pensionerTaxFreeAmount : TaxRates2026.defaultTaxFreeAmount
        }
        return Double(taxFreeAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Solve for gross from employer cost
    private func grossFromEmployerCost(_ cost: Double) -> Double {
        guard cost > 0 else { return 0 }
        let minSocialTax = TaxRates2026.minSocialTaxBasis * TaxRates2026.socialTaxRate
        if useMinSocialTaxBasis {
            let divisor = 1 + (includeEmployerUI ? TaxRates2026.employerUnemploymentRate : 0)
            return (cost - minSocialTax) / divisor
        }
        let divisor = 1 + TaxRates2026.socialTaxRate + (includeEmployerUI ? TaxRates2026.employerUnemploymentRate : 0)
        return cost / divisor
    }

    /// Solve for gross from net (iterative)
    private func grossFromNet(_ targetNet: Double) -> Double {
        guard targetNet > 0 else { return 0 }
        var low = targetNet
        var high = targetNet * 2.5
        for _ in 0..<50 {
            let mid = (low + high) / 2
            let net = netFromGross(mid)
            if abs(net - targetNet) < 0.01 { return mid }
            if net < targetNet { low = mid }
            else { high = mid }
        }
        return (low + high) / 2
    }

    private func grossSalary() -> Double {
        switch inputMode {
        case .employerCost: return grossFromEmployerCost(inputValue)
        case .gross: return inputValue
        case .net: return grossFromNet(inputValue)
        }
    }

    private func socialTaxBasis() -> Double {
        if useMinSocialTaxBasis { return TaxRates2026.minSocialTaxBasis }
        return grossSalary()
    }

    private func socialTax() -> Double {
        socialTaxBasis() * TaxRates2026.socialTaxRate
    }

    private func employerUnemploymentInsurance() -> Double {
        includeEmployerUI ? grossSalary() * TaxRates2026.employerUnemploymentRate : 0
    }

    private func employerTotalCost() -> Double {
        grossSalary() + socialTax() + employerUnemploymentInsurance()
    }

    private func pensionContribution() -> Double {
        includePension ? grossSalary() * (pensionRate / 100) : 0
    }

    private func employeeUnemploymentInsurance() -> Double {
        (includeEmployeeUI && !isPensioner) ? grossSalary() * TaxRates2026.employeeUnemploymentRate : 0
    }

    private func taxableIncome() -> Double {
        max(0, grossSalary() - pensionContribution() - effectiveTaxFree)
    }

    private func incomeTax() -> Double {
        taxableIncome() * TaxRates2026.incomeTaxRate
    }

    private func netFromGross(_ gross: Double) -> Double {
        let pension = includePension ? gross * (pensionRate / 100) : 0
        let empUI = (includeEmployeeUI && !isPensioner) ? gross * TaxRates2026.employeeUnemploymentRate : 0
        let taxable = max(0, gross - pension - effectiveTaxFree)
        let incomeTaxAmount = taxable * TaxRates2026.incomeTaxRate
        return gross - pension - empUI - incomeTaxAmount
    }

    private func netSalary() -> Double {
        netFromGross(grossSalary())
    }

    private func percentOfEmployerCost(_ value: Double) -> Double {
        let total = employerTotalCost()
        guard total > 0 else { return 0 }
        return (value / total) * 100
    }

    // MARK: - Copy to clipboard

    private func copySalaryToClipboard() {
        let fmt = { (v: Double) in fmtNum(v, decimals: 2, suffix: "€") }
        let lines = [
            "Palgaarvutus (2026 määrad, EMTA)",
            "───────────────────────────────",
            "Tööandja kulu kokku:            \(fmt(employerTotalCost()))",
            "  Sotsiaalmaks (33%):           \(fmt(socialTax()))",
            "  Tööandja töötuskindlustus:    \(fmt(employerUnemploymentInsurance()))",
            "Brutopalk:                      \(fmt(grossSalary()))",
            "  Kogumispension (\(Int(pensionRate))%):         \(fmt(pensionContribution()))",
            "  Töötaja töötuskindlustus:     \(fmt(employeeUnemploymentInsurance()))",
            "  Tulumaks (22%):               \(fmt(incomeTax()))",
            "───────────────────────────────",
            "Netopalk:                       \(fmt(netSalary()))"
        ]
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        copyConfirmed = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copyConfirmed = false
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Lähteandmed
                    CardContainer(title: "Lähteandmed", icon: "doc.text") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Sisend", selection: $inputMode) {
                                ForEach(SalaryInputMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("Summa (€)")
                                    .frame(width: 100, alignment: .leading)
                                TextField("0,00", text: $inputAmount)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 90, maxWidth: 140)
                                Text("kuus")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Toggle(isOn: $useTaxFreeCheckbox) {
                                Text("Maksuvaba tulu")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .toggleStyle(.checkbox)

                            if useTaxFreeCheckbox {
                                Toggle(isOn: $useAutoTaxFree) {
                                    Text("Arvesta maksuvaba tulu (700 € kuus)")
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .toggleStyle(.checkbox)

                                if !useAutoTaxFree {
                                    LabeledField(
                                        label: "Maksuvaba tulu (€)",
                                        text: $taxFreeAmount,
                                        placeholder: "700"
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minWidth: 280)

                    // Mahaarvamised
                    CardContainer(title: "Mahaarvamised", icon: "list.bullet") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $useMinSocialTaxBasis) {
                                Text("Arvesta sotsiaalmaksu min. kuumäära alusel")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .toggleStyle(.checkbox)

                            Toggle(isOn: $isPensioner) {
                                Text("Töötaja on vanaduspensioniealine")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .toggleStyle(.checkbox)

                            Toggle(isOn: $includeEmployerUI) {
                                Text("Tööandja töötuskindlustusmakse (0,8%)")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .toggleStyle(.checkbox)

                            Toggle(isOn: $includeEmployeeUI) {
                                Text("Töötaja töötuskindlustusmakse (1,6%)")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .toggleStyle(.checkbox)

                            Toggle(isOn: $includePension) {
                                Text("Kogumispension (II sammas)")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .toggleStyle(.checkbox)

                            if includePension {
                                HStack(alignment: .center, spacing: 8) {
                                    Text("Määr:")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: Binding(
                                        get: { Int(pensionRate) },
                                        set: { pensionRate = Double($0) }
                                    )) {
                                        Text("2%").tag(2)
                                        Text("4%").tag(4)
                                        Text("6%").tag(6)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 70)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minWidth: 280)
                }
                .frame(width: 640)

                // Tulemus
                CardContainer(title: "Tulemus", icon: "eurosign.circle") {
                    VStack(spacing: 0) {
                        // Visual breakdown bar
                        if employerTotalCost() > 0 {
                            SalaryBreakdownBar(
                                segments: [
                                    ("Sotsiaalmaks", socialTax(), Color.purple.opacity(0.75)),
                                    ("TK tööandja", employerUnemploymentInsurance(), Color.indigo.opacity(0.75)),
                                    ("Pension", pensionContribution(), Color.blue.opacity(0.75)),
                                    ("TK töötaja", employeeUnemploymentInsurance(), Color.teal.opacity(0.75)),
                                    ("Tulumaks", incomeTax(), Color.orange.opacity(0.85)),
                                    ("Netopalk", netSalary(), Color.green.opacity(0.75))
                                ],
                                total: employerTotalCost()
                            )
                            .padding(.bottom, 12)
                        }

                        SalaryResultHeader()
                            .padding(.trailing, 8)
                        Divider()
                            .padding(.vertical, 4)
                        SalaryResultRow(title: "Tööandja kulu kokku (palgafond):", eur: employerTotalCost(), percent: 100)
                        SalaryResultRow(title: "Sotsiaalmaks:", eur: socialTax(), percent: percentOfEmployerCost(socialTax()))
                        SalaryResultRow(title: "Töötuskindlustusmakse (tööandja):", eur: employerUnemploymentInsurance(), percent: percentOfEmployerCost(employerUnemploymentInsurance()))
                        SalaryResultRow(title: "Brutopalk:", eur: grossSalary(), percent: percentOfEmployerCost(grossSalary()))
                        SalaryResultRow(title: "Kogumispension (II sammas):", eur: pensionContribution(), percent: percentOfEmployerCost(pensionContribution()))
                        SalaryResultRow(title: "Töötuskindlustusmakse (töötaja):", eur: employeeUnemploymentInsurance(), percent: percentOfEmployerCost(employeeUnemploymentInsurance()))
                        SalaryResultRow(title: "Tulumaks:", eur: incomeTax(), percent: percentOfEmployerCost(incomeTax()))
                        SalaryResultRow(title: "Netopalk:", eur: netSalary(), percent: percentOfEmployerCost(netSalary()))

                        // Copy button
                        HStack {
                            Spacer()
                            Button {
                                copySalaryToClipboard()
                            } label: {
                                Label(
                                    copyConfirmed ? "Kopeeritud!" : "Kopeeri tulemused",
                                    systemImage: copyConfirmed ? "checkmark.circle.fill" : "doc.on.clipboard"
                                )
                                .font(.caption)
                                .foregroundStyle(copyConfirmed ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 8)
                    }
                }
                .frame(width: 632, alignment: .leading)

                Text("2026. aasta määrad (EMTA)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(minWidth: 620)
        }
        .frame(minWidth: 820, minHeight: 520)
        .background(
            LinearGradient(
                colors: [Color("AppBackground"), Color(red: 0.76, green: 0.85, blue: 0.79)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Salary Breakdown Bar

private struct SalaryBreakdownBar: View {
    let segments: [(label: String, value: Double, color: Color)]
    let total: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(segments.indices, id: \.self) { i in
                        let fraction = total > 0 ? max(0, segments[i].value / total) : 0
                        let width = geo.size.width * fraction
                        if width >= 2 {
                            Rectangle()
                                .fill(segments[i].color)
                                .frame(width: width)
                        }
                    }
                }
            }
            .frame(height: 18)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // Legend
            HStack(spacing: 12) {
                ForEach(segments.indices, id: \.self) { i in
                    if segments[i].value > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(segments[i].color)
                                .frame(width: 7, height: 7)
                            Text(segments[i].label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Result subviews

private struct SalaryResultHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("EUR")
                .frame(width: 90, alignment: .trailing)
                .font(.subheadline.weight(.medium))
            Text("%")
                .frame(width: 50, alignment: .trailing)
                .font(.subheadline.weight(.medium))
        }
        .padding(.vertical, 6)
        .padding(.trailing, 8)
        .foregroundStyle(.secondary)
    }
}

private struct SalaryResultRow: View {
    let title: String
    let eur: Double
    let percent: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(fmtNum(eur, decimals: 2, suffix: "€"))
                .font(.body.monospacedDigit().weight(.medium))
                .frame(width: 90, alignment: .trailing)
            Text(String(format: "%.2f", percent))
                .font(.body.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .padding(.trailing, 8)
    }
}

#Preview {
    SalaryTaxView()
        .frame(width: 740, height: 680)
}
