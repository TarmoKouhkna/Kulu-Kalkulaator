//
//  FuelPriceService.swift
//  KutuseKalkulaator
//
//  Fetches Estonian fuel prices from public sources.
//  Primary: pistik.net, Secondary: fuel-prices.eu, Fallback: manual entry
//

import Foundation

/// Fuel type identifiers matching the app's dropdown
enum FuelType: String, CaseIterable, Codable {
    case bensin95 = "95"
    case bensin98 = "98"
    case diesel = "Diesel"
    case lpg = "LPG"
    
    var displayName: String { rawValue }
}

/// Result of a price fetch attempt
struct FuelPrices: Equatable {
    let price95: Double?
    let price98: Double?
    let priceDiesel: Double?
    let priceLPG: Double?
    let lastUpdated: Date
    let source: String
    
    func price(for fuelType: FuelType) -> Double? {
        switch fuelType {
        case .bensin95: return price95
        case .bensin98: return price98
        case .diesel: return priceDiesel
        case .lpg: return priceLPG
        }
    }
}

@MainActor
final class FuelPriceService: ObservableObject {
    static let shared = FuelPriceService()
    
    @Published private(set) var prices: FuelPrices?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetch current Estonian fuel prices. Tries sources in order.
    func fetchPrices() async {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        // 1. Try pistik.ee / pistik.net (has 95, 98, Diesel - clear structure)
        if let p = await fetchFromPistik(url: "https://www.pistik.ee/kutusehinnad-eestis") {
            prices = p
            return
        }
        if let p = await fetchFromPistik(url: "https://www.pistik.net/kutusehinnad-eestis") {
            prices = p
            return
        }
        
        // 2. Try fuel-prices.eu (has 95, Diesel)
        if let p = await fetchFromFuelPricesEU() {
            prices = p
            return
        }
        
        // 3. Try kursikas.ee (may be blocked)
        if let p = await fetchFromKursikas() {
            prices = p
            return
        }
        
        lastError = "Hindade laadimine ebaõnnestus — sisesta käsitsi"
        // Keep previous prices if any, so user can still use manual override
        if prices == nil {
            prices = FuelPrices(
                price95: nil,
                price98: nil,
                priceDiesel: nil,
                priceLPG: nil,
                lastUpdated: Date(),
                source: "Manuaalne"
            )
        }
    }
    
    /// Parse pistik.ee / pistik.net - has 95, 98, Diisel in clear format
    private func fetchFromPistik(url urlString: String) async -> FuelPrices? {
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        
        do {
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            // Pattern: number (X.XXX or XXXX) followed by EUR
            let pricePattern = #"(\d{1,2}[.,]?\d*)\s*EUR"#
            guard let regex = try? NSRegularExpression(pattern: pricePattern) else { return nil }
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            
            var foundPrices: [Double] = []
            for m in matches {
                if let r = Range(m.range(at: 1), in: html) {
                    let numStr = String(html[r]).replacingOccurrences(of: ",", with: ".")
                    if let d = parsePrice(numStr) {
                        // Normalize: 1729 -> 1.729, 1.599 stays 1.599
                        let normalized = d > 100 ? d / 1000 : d
                        if normalized > 0.5, normalized < 3.0 {
                            foundPrices.append(normalized)
                        }
                    }
                }
            }
            
            // Pistik order: 95, 98, Diisel - take first 3 unique-ish
            var p95: Double?
            var p98: Double?
            var pDiesel: Double?
            if foundPrices.count >= 3 {
                p95 = foundPrices[0]
                p98 = foundPrices[1]
                pDiesel = foundPrices[2]
            } else if foundPrices.count >= 2 {
                p95 = foundPrices[0]
                p98 = foundPrices[1]
            } else if foundPrices.count >= 1 {
                p95 = foundPrices[0]
            }
            
            if p95 != nil || p98 != nil || pDiesel != nil {
                let host = url.host ?? "pistik"
                return FuelPrices(
                    price95: p95,
                    price98: p98,
                    priceDiesel: pDiesel,
                    priceLPG: 0.68, // Pistik table shows Eesti LPG ~0.68
                    lastUpdated: Date(),
                    source: host
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
        return nil
    }
    
    /// Parse fuel-prices.eu/Estonia/ - has Euro 95 and Diesel
    private func fetchFromFuelPricesEU() async -> FuelPrices? {
        guard let url = URL(string: "https://www.fuel-prices.eu/Estonia/") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            var p95: Double?
            var p98: Double?
            var pDiesel: Double?
            
            // fuel-prices.eu format: €1.587, €1.688
            let euroPattern = #"€(\d+\.?\d*)"#
            if let regex = try? NSRegularExpression(pattern: euroPattern) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, range: range)
                var values: [Double] = []
                for m in matches {
                    if let r = Range(m.range(at: 1), in: html),
                       let d = Double(String(html[r])), d > 0.5, d < 3.0 {
                        values.append(d)
                    }
                }
                // First is typically 95, second Diesel; 98 often not shown - estimate from 95
                if values.count >= 2 {
                    p95 = values[0]
                    pDiesel = values[1]
                    p98 = p95.map { $0 + 0.06 } // typical 98 premium
                }
            }
            
            if p95 != nil || pDiesel != nil {
                return FuelPrices(
                    price95: p95,
                    price98: p98,
                    priceDiesel: pDiesel,
                    priceLPG: 0.68,
                    lastUpdated: Date(),
                    source: "fuel-prices.eu"
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
        return nil
    }
    
    /// Parse kursikas.ee/kytus - may return 503
    private func fetchFromKursikas() async -> FuelPrices? {
        guard let url = URL(string: "https://www.kursikas.ee/kytus") else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else { return nil }
            
            // Parse table if structure is similar - adjust based on actual HTML
            var p95: Double?
            var p98: Double?
            var pDiesel: Double?
            let pricePattern = #"(\d+[.,]\d+)\s*€"#
            if let regex = try? NSRegularExpression(pattern: pricePattern) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, range: range)
                var values: [Double] = []
                for m in matches {
                    if let r = Range(m.range(at: 1), in: html) {
                        let s = String(html[r]).replacingOccurrences(of: ",", with: ".")
                        if let d = Double(s), d > 0.5, d < 3.0 { values.append(d) }
                    }
                }
                if values.count >= 2 {
                    p95 = values[0]
                    pDiesel = values.count > 1 ? values[1] : nil
                    p98 = values.count > 2 ? values[2] : p95.map { $0 + 0.06 }
                }
            }
            
            if p95 != nil || pDiesel != nil {
                return FuelPrices(
                    price95: p95,
                    price98: p98,
                    priceDiesel: pDiesel,
                    priceLPG: 0.68,
                    lastUpdated: Date(),
                    source: "kursikas.ee"
                )
            }
        } catch {
            lastError = error.localizedDescription
        }
        return nil
    }
    
    private func parsePrice(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
        if let d = Double(cleaned) {
            if d > 100 { return d / 1000 } // 1729 -> 1.729
            return d
        }
        return nil
    }
    
    /// Allow manual price override when fetch fails
    func setManualPrice(_ price: Double, for fuelType: FuelType) {
        let current = prices ?? FuelPrices(
            price95: nil, price98: nil, priceDiesel: nil, priceLPG: nil,
            lastUpdated: Date(), source: "Manuaalne"
        )
        var p95 = current.price95
        var p98 = current.price98
        var pDiesel = current.priceDiesel
        var pLPG = current.priceLPG
        switch fuelType {
        case .bensin95: p95 = price
        case .bensin98: p98 = price
        case .diesel: pDiesel = price
        case .lpg: pLPG = price
        }
        prices = FuelPrices(
            price95: p95, price98: p98, priceDiesel: pDiesel, priceLPG: pLPG,
            lastUpdated: Date(), source: "Manuaalne"
        )
        lastError = nil
    }
}
