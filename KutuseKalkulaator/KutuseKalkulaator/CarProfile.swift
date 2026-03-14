//
//  CarProfile.swift
//  KutuseKalkulaator
//
//  Model for car configuration with UserDefaults persistence.
//

import Foundation

struct CarProfile: Codable, Equatable {
    var carName: String
    var fuelType: FuelType
    var consumptionLPer100km: Double
    var tankSizeL: Double
    
    static let `default` = CarProfile(
        carName: "",
        fuelType: .bensin95,
        consumptionLPer100km: 7.0,
        tankSizeL: 50.0
    )
    
    static let storageKey = "KutuseKalkulaator.CarProfile"
    
    static func load() -> CarProfile {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(CarProfile.self, from: data) else {
            return .default
        }
        return profile
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: CarProfile.storageKey)
        }
    }
}
