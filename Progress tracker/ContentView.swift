//
//  ContentView.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 08.07.2024.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            CompletedGoalsView()
                .tabItem {
                    Label("Menu", systemImage: "list.dash")
                }
        }
    }
}

#Preview {
    TabView {
        ContentView()
            .modelContainer(for: Goal.self, inMemory: true)
    }
}
