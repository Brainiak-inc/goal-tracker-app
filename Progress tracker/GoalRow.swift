//
//  GoalRow.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 15.07.2024.
//

import SwiftUI

struct GoalRow: View {
    let goal: Goal
    var body: some View {
        HStack{
            Text(goal.title)
            ProgressBar()
        }
    }
}

#Preview {
    GoalRow(goal: Goal(title: "", isCompleted: false))
}
