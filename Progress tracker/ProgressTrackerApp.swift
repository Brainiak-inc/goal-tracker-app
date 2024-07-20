//
//  Progress_trackerApp.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 08.07.2024.
//

import SwiftUI
import SwiftData

@main
struct ProgressTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Goal.self)
    }
}
