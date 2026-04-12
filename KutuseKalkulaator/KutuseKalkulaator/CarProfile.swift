//
//  CarProfile.swift
//  KutuseKalkulaator
//
//  Model for car configuration with UserDefaults persistence.
//  Supports multiple profiles with migration from legacy single-profile storage.
//

import Foundation

struct CarProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var carName: String
    var fuelType: FuelType
    var consumptionLPer100km: Double
    var tankSizeL: Double

    init(id: UUID = UUID(), carName: String, fuelType: FuelType, consumptionLPer100km: Double, tankSizeL: Double) {
        self.id = id
        self.carName = carName
        self.fuelType = fuelType
        self.consumptionLPer100km = consumptionLPer100km
        self.tankSizeL = tankSizeL
    }

    static let `default` = CarProfile(
        carName: "",
        fuelType: .bensin95,
        consumptionLPer100km: 7.0,
        tankSizeL: 50.0
    )

    // MARK: - Storage keys

    private static let legacyKey    = "KutuseKalkulaator.CarProfile"
    private static let arrayKey     = "KutuseKalkulaator.CarProfiles"
    private static let selectedKey  = "KutuseKalkulaator.SelectedProfileId"

    // MARK: - Persistence

    static func loadAll() -> [CarProfile] {
        // Try loading new array format
        if let data = UserDefaults.standard.data(forKey: arrayKey),
           let profiles = try? JSONDecoder().decode([CarProfile].self, from: data),
           !profiles.isEmpty {
            return profiles
        }

        // Migrate from legacy single-profile (no id field)
        if let data = UserDefaults.standard.data(forKey: legacyKey),
           let old = try? JSONDecoder().decode(LegacyCarProfile.self, from: data) {
            let migrated = CarProfile(
                carName: old.carName,
                fuelType: old.fuelType,
                consumptionLPer100km: old.consumptionLPer100km,
                tankSizeL: old.tankSizeL
            )
            saveAll([migrated])
            return [migrated]
        }

        return [.default]
    }

    static func saveAll(_ profiles: [CarProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: arrayKey)
        }
    }

    static func loadSelectedId() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: selectedKey) else { return nil }
        return UUID(uuidString: str)
    }

    static func saveSelectedId(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: selectedKey)
    }
}

// Legacy struct for migration (original format had no id field)
private struct LegacyCarProfile: Codable {
    var carName: String
    var fuelType: FuelType
    var consumptionLPer100km: Double
    var tankSizeL: Double
}
