//
//  CalculatorViewModel.swift
//  KutuseKalkulaator
//
//  Central calculation logic and state for the fuel calculator.
//

import Foundation
import Combine

@MainActor
final class CalculatorViewModel: ObservableObject {
    // Car setup
    @Published var carName: String { didSet { profile.carName = carName; profile.save() } }
    @Published var fuelType: FuelType {
        didSet {
            profile.fuelType = fuelType
            profile.save()
            manualPricePerLitre = "" // Clear manual override when switching fuel type
        }
    }
    @Published var consumptionLPer100km: String { didSet { profile.consumptionLPer100km = consumptionValue; profile.save() } }
    @Published var tankSizeL: String { didSet { profile.tankSizeL = tankSizeValue; profile.save() } }
    
    // Fuel price (from service or manual)
    @Published var manualPricePerLitre: String = ""
    
    // Distance calculator
    @Published var distanceKm: String = ""
    
    private var profile: CarProfile
    private let fuelPriceService: FuelPriceService
    private var cancellables = Set<AnyCancellable>()
    
    init(fuelPriceService: FuelPriceService) {
        self.fuelPriceService = fuelPriceService
        self.profile = CarProfile.load()
        self.carName = profile.carName
        self.fuelType = profile.fuelType
        self.consumptionLPer100km = Self.formatNumber(profile.consumptionLPer100km)
        self.tankSizeL = Self.formatNumber(profile.tankSizeL)
        
        fuelPriceService.$prices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
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
    var priceSource: String? { fuelPriceService.prices?.source }
    var priceFetchError: String? { fuelPriceService.lastError }
    var isPriceLoading: Bool { fuelPriceService.isLoading }
    
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
