//
//  KutuseKalkulaatorApp.swift
//  KutuseKalkulaator
//
//  Estonian Fuel Calculator - macOS app entry point.
//

import SwiftUI

@main
struct KutuseKalkulaatorApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .navigationTitle("Kulu-Kalkulaator")
                .preferredColorScheme(nil) // Follow system
        }
        .windowStyle(.automatic)
        .defaultSize(width: 800, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
