//
//  CalculatorViewModel.swift
//  KutuseKalkulaator
//
//  Central calculation logic and state for the fuel calculator.
//  Supports multiple car profiles and auto-refreshes fuel prices every 30 minutes.
//

import Foundation
import Combine

@MainActor
final class CalculatorViewModel: ObservableObject {
    // Profiles
    @Published var profiles: [CarProfile]
    @Published var selectedProfileId: UUID {
        didSet {
            loadSelectedProfile()
            CarProfile.saveSelectedId(selectedProfileId)
        }
    }

    // Car setup (bound to selected profile)
    @Published var carName: String = "" { didSet { saveCurrentProfile() } }
    @Published var fuelType: FuelType = .bensin95 {
        didSet {
            saveCurrentProfile()
            manualPricePerLitre = ""
        }
    }
    @Published var consumptionLPer100km: String = "" { didSet { saveCurrentProfile() } }
    @Published var tankSizeL: String = ""             { didSet { saveCurrentProfile() } }

    // Fuel price (from service or manual)
    @Published var manualPricePerLitre: String = ""

    // Distance calculator
    @Published var distanceKm: String = ""

    private var isLoadingProfile = false
    private let fuelPriceService: FuelPriceService
    private var cancellables = Set<AnyCancellable>()

    init(fuelPriceService: FuelPriceService) {
        self.fuelPriceService = fuelPriceService

        var loaded = CarProfile.loadAll()
        if loaded.isEmpty { loaded = [.default] }

        let selId: UUID
        if let saved = CarProfile.loadSelectedId(), loaded.contains(where: { $0.id == saved }) {
            selId = saved
        } else {
            selId = loaded[0].id
        }

        let current = loaded.first(where: { $0.id == selId }) ?? loaded[0]

        self.profiles = loaded
        self.selectedProfileId = selId
        self.carName = current.carName
        self.fuelType = current.fuelType
        self.consumptionLPer100km = Self.formatNumber(current.consumptionLPer100km)
        self.tankSizeL = Self.formatNumber(current.tankSizeL)

        fuelPriceService.$prices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        fuelPriceService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Auto-refresh fuel prices every 30 minutes
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(1800))
                await self?.refreshPrices()
            }
        }
    }

    // MARK: - Profile management

    func addProfile() {
        let new = CarProfile(carName: "Uus auto", fuelType: .bensin95, consumptionLPer100km: 7.0, tankSizeL: 50.0)
        profiles.append(new)
        CarProfile.saveAll(profiles)
        selectedProfileId = new.id
    }

    func deleteCurrentProfile() {
        guard profiles.count > 1 else { return }
        guard let idx = profiles.firstIndex(where: { $0.id == selectedProfileId }) else { return }
        profiles.remove(at: idx)
        CarProfile.saveAll(profiles)
        selectedProfileId = profiles[min(idx, profiles.count - 1)].id
    }

    private func loadSelectedProfile() {
        guard let p = profiles.first(where: { $0.id == selectedProfileId }) else { return }
        isLoadingProfile = true
        carName = p.carName
        fuelType = p.fuelType
        consumptionLPer100km = Self.formatNumber(p.consumptionLPer100km)
        tankSizeL = Self.formatNumber(p.tankSizeL)
        manualPricePerLitre = ""
        isLoadingProfile = false
    }

    private func saveCurrentProfile() {
        guard !isLoadingProfile else { return }
        guard let idx = profiles.firstIndex(where: { $0.id == selectedProfileId }) else { return }
        profiles[idx].carName = carName
        profiles[idx].fuelType = fuelType
        profiles[idx].consumptionLPer100km = consumptionValue
        profiles[idx].tankSizeL = tankSizeValue
        CarProfile.saveAll(profiles)
    }

    // MARK: - Parsed values

    var consumptionValue: Double {
        Double(consumptionLPer100km.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var tankSizeValue: Double {
        Double(tankSizeL.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var distanceValue: Double {
        Double(distanceKm.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Effective price per litre: from service, or manual override
    var pricePerLitre: Double? {
        if let manual = Double(manualPricePerLitre.replacingOccurrences(of: ",", with: ".")),
           manual > 0 { return manual }
        return fuelPriceService.prices?.price(for: fuelType)
    }

    // MARK: - Results (full tank)

    /// Full tank range: (tank size / consumption) × 100 = km
    var fullTankRangeKm: Double? {
        guard consumptionValue > 0, tankSizeValue > 0 else { return nil }
        return (tankSizeValue / consumptionValue) * 100
    }

    /// Full tank cost: tank size × price per litre
    var fullTankCostEur: Double? {
        guard let price = pricePerLitre, price > 0, tankSizeValue > 0 else { return nil }
        return tankSizeValue * price
    }

    /// Cost per km: price × (consumption / 100)
    var costPerKmEur: Double? {
        guard let price = pricePerLitre, price > 0, consumptionValue > 0 else { return nil }
        return price * (consumptionValue / 100)
    }

    // MARK: - Distance calculator

    /// Litres needed for distance
    var litresNeeded: Double? {
        guard distanceValue > 0, consumptionValue > 0 else { return nil }
        return distanceValue * (consumptionValue / 100)
    }

    /// Cost for distance
    var distanceCostEur: Double? {
        guard let litres = litresNeeded, let price = pricePerLitre, price > 0 else { return nil }
        return litres * price
    }

    // MARK: - Helpers

    private static func formatNumber(_ d: Double) -> String {
        if d == 0 { return "" }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        return formatter.string(from: NSNumber(value: d)) ?? "\(d)"
    }

    var lastPriceUpdate: Date? { fuelPriceService.prices?.lastUpdated }
    var priceSource: String?   { fuelPriceService.prices?.source }
    var priceFetchError: String? { fuelPriceService.lastError }
    var isPriceLoading: Bool   { fuelPriceService.isLoading }

    func refreshPrices() async {
        await fuelPriceService.fetchPrices()
    }

    func setManualPrice(_ price: Double) {
        fuelPriceService.setManualPrice(price, for: fuelType)
        if price > 0 {
            manualPricePerLitre = Self.formatNumber(price)
        }
    }

    /// Apply manual price from text field (clears fetch error when valid)
    func applyManualPrice() {
        if let p = Double(manualPricePerLitre.replacingOccurrences(of: ",", with: ".")), p > 0 {
            setManualPrice(p)
        }
    }
}
