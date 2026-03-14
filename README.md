# Kulu-Kalkulaator

Estonian cost calculator — a native macOS app built with SwiftUI. Multiple calculators in one place.

## Features

### Kütusekalkulaator (Fuel Calculator)
- **Car Setup**: Name, fuel type (95, 98, Diesel, LPG), consumption (L/100km), tank size
- **Live Estonian Fuel Prices**: Fetches from pistik.ee, fuel-prices.eu, or kursikas.ee
- **Results Dashboard**: Full tank range, full tank cost, cost per km (auto-updates as you type)
- **Distance Calculator**: Enter distance → litres needed and cost
- **Manual Price Fallback**: If fetch fails, enter price manually
- **Persistence**: Car profile saved in UserDefaults

### Käibemaks (VAT Calculator)
- Convert between net and gross amounts
- Preset rates: 24% (standard), 13% (accommodation), 9% (books, medicines, etc.), 0% (exempt)
- Custom rate input supported
- Based on Estonian VAT rates (EMTA)

### Laen (Loan Calculator)
- Monthly payment, total paid, total interest
- Downpayment (Sissemakse) as percentage or fixed amount
- Standard amortization formula

### Palk (Salary Tax Calculator)
- 2026 Estonian rates (EMTA)
- Input: Employer cost, gross salary, or net salary
- Deductions: Social tax, unemployment insurance, pension (2nd pillar)
- Tax-free income (700 €/month, 776 € for pensioners)
- Results: Employer cost, social tax, gross, pension, income tax, net

## Requirements

- macOS 14.0+
- Xcode 15+

## Build & Run

1. Open `KutuseKalkulaator.xcodeproj` in Xcode
2. Select the **KutuseKalkulaator** scheme
3. Press ⌘R to build and run

Or from Terminal (with full Xcode installed):

```bash
cd KutuseKalkulaator
xcodebuild -scheme KutuseKalkulaator -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Kulu-Kalkulaator.app
```

## Release Build

To build for distribution:

```bash
cd KutuseKalkulaator
xcodebuild -scheme KutuseKalkulaator -configuration Release -derivedDataPath build build
```

The app will be at `build/Build/Products/Release/Kulu-Kalkulaator.app`. Compress it to share.

## Project Structure

```
KutuseKalkulaator/
├── KutuseKalkulaator.xcodeproj/
├── KutuseKalkulaator/
│   ├── KutuseKalkulaatorApp.swift   # App entry point
│   ├── MainTabView.swift            # Tab navigation
│   ├── ContentView.swift            # Fuel calculator
│   ├── SalesTaxView.swift           # VAT (käibemaks) calculator
│   ├── LoanCalculatorView.swift     # Loan calculator
│   ├── SalaryTaxView.swift          # Salary tax calculator
│   ├── FuelPriceService.swift       # Fetches Estonian fuel prices
│   ├── CarProfile.swift             # Model + UserDefaults persistence
│   ├── CalculatorViewModel.swift    # Fuel calculation logic
│   ├── Assets.xcassets/
│   ├── Info.plist
│   └── KutuseKalkulaator.entitlements
└── project.yml                       # XcodeGen config (optional)
```

## Fuel Price Sources

The app tries these sources in order:

1. **pistik.ee** — 95, 98, Diesel
2. **fuel-prices.eu** — Euro 95, Diesel
3. **kursikas.ee** — May return 503

If all fail, a manual input field appears. Add `User-Agent: Mozilla/5.0` if requests are blocked.

## Design

- Light sage background (#B6CBBD)
- Accent color: warm amber
- Dark mode support (follows system)
- SF Symbols: fuelpump.fill, percent, banknote, person.crop.circle.badge.checkmark, eurosign.circle
