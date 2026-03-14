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
        .background(Color("AppBackground"))
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
                HStack {
                    if let price = viewModel.pricePerLitre {
                        Text(String(format: "%.3f €/L", price))
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.primary)
                    } else {
                        Text("— €/L")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task { await viewModel.refreshPrices() }
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .symbolEffect(.bounce, value: viewModel.isPriceLoading)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPriceLoading)
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
            VStack(spacing: 16) {
                ResultRow(
                    title: "Täistankimise ulatus",
                    value: viewModel.fullTankRangeKm.map { String(format: "%.0f km", $0) },
                    subtitle: "Paagi maht ÷ kulu × 100"
                )
                ResultRow(
                    title: "Täistankimise maksumus",
                    value: viewModel.fullTankCostEur.map { String(format: "%.2f €", $0) },
                    subtitle: "Paagi maht × hind"
                )
                ResultRow(
                    title: "Kulu km kohta",
                    value: viewModel.costPerKmEur.map { String(format: "%.3f €/km", $0) },
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
                        value: viewModel.litresNeeded.map { String(format: "%.1f L", $0) },
                        subtitle: nil
                    )
                    ResultRow(
                        title: "Maksumus",
                        value: viewModel.distanceCostEur.map { String(format: "%.2f €", $0) },
                        subtitle: nil
                    )
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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 120, alignment: .leading)
            Spacer(minLength: 8)
            if let v = value {
                Text(v)
                    .font(.body.monospacedDigit().weight(.medium))
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: v)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text("—")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .frame(width: 520, height: 640)
}
