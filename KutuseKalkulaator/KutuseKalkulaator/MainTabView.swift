//
//  MainTabView.swift
//  KutuseKalkulaator
//
//  Root view with tabs for Fuel Calculator, Sales Tax (Käibemaks), Loan, and Salary.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("Kütusekalkulaator", systemImage: "fuelpump.fill")
                }
                .tag(0)
            
            SalesTaxView()
                .tabItem {
                    Label("Käibemaks", systemImage: "percent")
                }
                .tag(1)
            
            LoanCalculatorView()
                .tabItem {
                    Label("Laen", systemImage: "banknote")
                }
                .tag(2)
            
            SalaryTaxView()
                .tabItem {
                    Label("Palk", systemImage: "person.crop.circle.badge.checkmark")
                }
                .tag(3)
        }
        .frame(minWidth: 820, minHeight: 780)
    }
}

#Preview {
    MainTabView()
        .frame(width: 650, height: 820)
}
