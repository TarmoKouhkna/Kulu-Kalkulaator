//
//  ContentView.swift
//  KutuseKalkulaator
//
//  Main view with Car Setup, Fuel Prices, Results, and Distance Calculator.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CalculatorViewModel(fuelPriceService: FuelPriceService.shared)
    
    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                CarSetupSection(viewModel: viewModel)
                FuelPriceSection(viewModel: viewModel)
                ResultsSection(viewModel: viewModel)
                DistanceCalculatorSection(viewModel: viewModel)
            }
            .padding(20)
            .frame(minWidth: 600)
        }
        .frame(minWidth: 620, minHeight: 780)
        .background(
            LinearGradient(
                colors: [
                    Color("AppBackground"),
                    Color(red: 0.76, green: 0.85, blue: 0.79)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .task {
            await viewModel.refreshPrices()
        }
    }
}

// MARK: - Car Setup Section

struct CarSetupSection: View {
    @ObservedObject var viewModel: CalculatorViewModel

    var body: some View {
        CardContainer(title: "Auto seaded", icon: "car.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // Profile picker
                HStack(spacing: 8) {
                    Picker("", selection: $viewModel.selectedProfileId) {
                        ForEach(viewModel.profiles) { profile in
                            Text(profile.carName.isEmpty ? "Nimetu auto" : profile.carName)
                                .tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Button {
                        viewModel.addProfile()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Lisa uus auto profiil")

                    Button {
                        viewModel.deleteCurrentProfile()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.red.opacity(viewModel.profiles.count > 1 ? 1 : 0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.profiles.count <= 1)
                    .help("Kustuta see profiil")
                }

                LabeledField(label: "Auto nimi/mudel", text: $viewModel.carName, placeholder: "nt. Toyota Corolla")
                
                HStack {
                    Text("Kütuse tüüp")
                        .frame(width: 140, alignment: .leading)
                    Picker("", selection: $viewModel.fuelType) {
                        ForEach(FuelType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                LabeledField(label: "Kütusekulu (L/100 km)", text: $viewModel.consumptionLPer100km, placeholder: "7,0")
                LabeledField(label: "Paagi maht (L)", text: $viewModel.tankSizeL, placeholder: "50")
            }
        }
    }
}

// MARK: - Fuel Price Section

struct FuelPriceSection: View {
    @ObservedObject var viewModel: CalculatorViewModel
    
    var body: some View {
        CardContainer(title: "Kütuse hind", icon: "fuelpump.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    if let price = viewModel.pricePerLitre {
                        Text(fmtNum(price, decimals: 3, suffix: "€/L"))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: price)
                    } else {
                        Text("— €/L")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    RefreshButton(isLoading: viewModel.isPriceLoading) {
                        Task { await viewModel.refreshPrices() }
                    }
                }
                
                if let source = viewModel.priceSource, let date = viewModel.lastPriceUpdate {
                    Text("\(source) · \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let error = viewModel.priceFetchError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        TextField("Sisesta hind €/L", text: $viewModel.manualPricePerLitre)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                            .onSubmit { viewModel.applyManualPrice() }
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Results Section

struct ResultsSection: View {
    @ObservedObject var viewModel: CalculatorViewModel
    
    var body: some View {
        CardContainer(title: "Tulemused", icon: "eurosign.circle") {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ResultRow(
                    title: "Täistankimise ulatus",
                    value: viewModel.fullTankRangeKm.map { fmtNum($0, decimals: 0, suffix: "km") },
                    subtitle: "Paagi maht ÷ kulu × 100"
                )
                ResultRow(
                    title: "Täistankimise maksumus",
                    value: viewModel.fullTankCostEur.map { fmtNum($0, decimals: 2, suffix: "€") },
                    subtitle: "Paagi maht × hind"
                )
                ResultRow(
                    title: "Kulu km kohta",
                    value: viewModel.costPerKmEur.map { fmtNum($0, decimals: 3, suffix: "€/km") },
                    subtitle: "Hind × (kulu ÷ 100)"
                )
            }
        }
    }
}

// MARK: - Distance Calculator Section

struct DistanceCalculatorSection: View {
    @ObservedObject var viewModel: CalculatorViewModel
    
    var body: some View {
        CardContainer(title: "Vahemaa kalkulaator", icon: "map") {
            VStack(alignment: .leading, spacing: 16) {
                LabeledField(label: "Vahemaa (km)", text: $viewModel.distanceKm, placeholder: "100")
                
                VStack(spacing: 12) {
                    ResultRow(
                        title: "Vajalik kütus",
                        value: viewModel.litresNeeded.map { fmtNum($0, decimals: 1, suffix: "L") },
                        subtitle: nil
                    )
                    ResultRow(
                        title: "Maksumus",
                        value: viewModel.distanceCostEur.map { fmtNum($0, decimals: 2, suffix: "€") },
                        subtitle: nil
                    )
                }
            }
        }
    }
}

// MARK: - Number formatting

/// Formats a number with thousands grouping (space) and Estonian decimal separator (,).
/// Example: fmtNum(10000.5, decimals: 2, suffix: "€") → "10 000,50 €"
func fmtNum(_ value: Double, decimals: Int, suffix: String = "") -> String {
    // Format without grouping first, then insert spaces manually (avoids macOS 15+ API)
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.minimumFractionDigits = decimals
    f.maximumFractionDigits = decimals
    f.usesGroupingSeparator = false
    f.decimalSeparator = ","
    guard let raw = f.string(from: NSNumber(value: value)) else {
        return suffix.isEmpty ? "\(value)" : "\(value) \(suffix)"
    }

    let parts = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
    let intDigits = Array(parts[0])
    let decPart   = parts.count > 1 ? "," + parts[1] : ""

    // Insert non-breaking space every 3 digits from the right
    var grouped = ""
    for (i, ch) in intDigits.enumerated() {
        if i > 0 && (intDigits.count - i) % 3 == 0 { grouped += "\u{00A0}" }
        grouped.append(ch)
    }

    let result = grouped + decPart
    return suffix.isEmpty ? result : "\(result) \(suffix)"
}

// MARK: - Refresh Button

private struct RefreshButton: View {
    let isLoading: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var spinAngle: Double = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .rotationEffect(.degrees(spinAngle))
                if isLoading {
                    Text("Laen...")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isLoading
                          ? Color.accentColor.opacity(0.15)
                          : isHovered
                              ? Color.primary.opacity(0.12)
                              : Color.primary.opacity(0.07))
            )
            .foregroundStyle(isLoading ? Color.accentColor : Color.primary)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onHover { isHovered = $0 }
        .onChange(of: isLoading) { _, loading in
            if loading {
                spinAngle = 0
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    spinAngle = 360
                }
            } else {
                withAnimation(.default) {
                    spinAngle = 0
                }
            }
        }
    }
}

// MARK: - Reusable Components

struct CardContainer<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

struct LabeledField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .frame(width: 140, alignment: .leading)
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140, maxWidth: .infinity)
        }
    }
}

struct ResultRow: View {
    let title: String
    let value: String?
    let subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let sub = subtitle {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if let v = value {
                Text(v)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: v)
            } else {
                Text("—")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

#Preview {
    ContentView()
        .frame(width: 520, height: 640)
}
