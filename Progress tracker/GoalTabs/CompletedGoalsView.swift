//
//  CompletedGoalsView.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 20.07.2024.
//

import SwiftUI
import SwiftData

struct CompletedGoalsView: View {
    @State var percent: CGFloat = 0
    @State var inputValue: String = ""
    
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: [.init(\Goal.title), .init(\Goal.creationDate, order: .reverse)], animation: .bouncy) private var goals: [Goal]
    
    @Query(filter: #Predicate<Goal>{!$0.isCompleted},
           sort: [.init(\Goal.title), .init(\Goal.creationDate, order: .reverse)], animation: .bouncy) private var remainigGoals: [Goal]
    
    
    var body: some View {
            NavigationSplitView {
                List {
                    Section("All goals") {
                        ForEach(goals) { goal in
                            NavigationLink {
                                DetailGoalView(goal: goal)
                            } label: {
                                GoalRow(goal: goal)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    Section("Not completed") {
                        ForEach(remainigGoals) { goal in GoalRow(goal: goal)
                            
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: addGoal) {
                            Label("Add goal", systemImage: "plus")
                        }
                    }
                }
            } detail: {
                Text("Select a goal")
            }
    }
    
    private func addGoal() {
        let newGoal = Goal(title: "Move to USA", isCompleted: false)
            modelContext.insert(newGoal)

    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(goals[index])
        }
    }
}
