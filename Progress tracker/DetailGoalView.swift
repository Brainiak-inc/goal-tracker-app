//
//  DetailGoalView.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 14.07.2024.
//

import SwiftUI

struct DetailGoalView: View {
    @Bindable var goal: Goal
    var body: some View {
        VStack {
            TextField("New goal", text: $goal.title)
                .textFieldStyle(.roundedBorder)
            Toggle(goal.isCompleted ? "Completed!" : "Open", isOn: $goal.isCompleted)
        }
        .padding()
    }
}
//
//#Preview {
//    DetailGoalView()
//}
