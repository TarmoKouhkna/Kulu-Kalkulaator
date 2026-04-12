//
//  SalesTaxView.swift
//  KutuseKalkulaator
//
//  Käibemaks (sales tax) calculator - convert between net and gross amounts.
//

import SwiftUI

enum SalesTaxInputMode: String, CaseIterable {
    case withoutTax = "Ilma käibemaksuta"
    case withTax = "Käibemaksuga"
}

struct VatRatePreset: Identifiable {
    let id: Double
    let label: String
    let description: String
    
    static let presets: [VatRatePreset] = [
        VatRatePreset(id: 24, label: "24%", description: "Standard"),
        VatRatePreset(id: 13, label: "13%", description: "Majutus"),
        VatRatePreset(id: 9, label: "9%", description: "Raamatud, ravimid jms"),
        VatRatePreset(id: 0, label: "0%", description: "Vabastatud")
    ]
}

struct SalesTaxView: View {
    @State private var taxRatePercent: String = "24"
    @State private var inputAmount: String = ""
    @State private var inputMode: SalesTaxInputMode = .withoutTax
    
    private var taxRate: Double {
        Double(taxRatePercent.replacingOccurrences(of: ",", with: ".")) ?? 24
    }
    
    private var inputValue: Double {
        Double(inputAmount.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    
    private var netAmount: Double? {
        guard inputValue > 0 else { return nil }
        switch inputMode {
        case .withoutTax: return inputValue
        case .withTax: return inputValue / (1 + taxRate / 100)
        }
    }
    
    private var grossAmount: Double? {
        guard inputValue > 0 else { return nil }
        switch inputMode {
        case .withoutTax: return inputValue * (1 + taxRate / 100)
        case .withTax: return inputValue
        }
    }
    
    private var taxAmount: Double? {
        guard let net = netAmount, let gross = grossAmount else { return nil }
        return gross - net
    }
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                CardContainer(title: "Käibemaksu kalkulaator", icon: "percent") {
                    VStack(alignment: .leading, spacing: 16) {
                        LabeledField(
                            label: "Käibemaksu määr (%)",
                            text: $taxRatePercent,
                            placeholder: "24"
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vali määr:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                ForEach(VatRatePreset.presets) { preset in
                                    Button {
                                        taxRatePercent = String(format: "%.0f", preset.id)
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(preset.label)
                                                .font(.subheadline.weight(.medium))
                                            Text(preset.description)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill((Double(taxRatePercent.replacingOccurrences(of: ",", with: ".")) ?? -1) == preset.id ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        Picker("Sisesta summa", selection: $inputMode) {
                            ForEach(SalesTaxInputMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        LabeledField(
                            label: inputMode == .withoutTax ? "Summa ilma käibemaksuta (€)" : "Summa käibemaksuga (€)",
                            text: $inputAmount,
                            placeholder: inputMode == .withoutTax ? "100,00" : "120,00"
                        )
                    }
                }
                
                CardContainer(title: "Tulemused", icon: "eurosign.circle") {
                    VStack(spacing: 12) {
                        ResultRow(
                            title: "Summa ilma käibemaksuta",
                            value: netAmount.map { fmtNum($0, decimals: 2, suffix: "€") },
                            subtitle: nil
                        )
                        ResultRow(
                            title: "Käibemaks (\(String(format: "%.0f", taxRate))%)",
                            value: taxAmount.map { fmtNum($0, decimals: 2, suffix: "€") },
                            subtitle: nil
                        )
                        ResultRow(
                            title: "Summa käibemaksuga",
                            value: grossAmount.map { fmtNum($0, decimals: 2, suffix: "€") },
                            subtitle: nil
                        )
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
    SalesTaxView()
        .frame(width: 520, height: 400)
}
