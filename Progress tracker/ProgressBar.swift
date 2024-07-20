//
//  ProgressBar.swift
//  Progress tracker
//
//  Created by Ilia Isaev on 08.07.2024.
//

import SwiftUI

struct ProgressBar: View {
    var width: CGFloat = 200
    var height: CGFloat = 20
    var percent: CGFloat = 10
    var color1 = Color(.green)
    var color2 = Color(.blue)
    
    var body: some View {
        let multiplier = width / 100
        
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerSize: CGSize(width: height, height: 10), style: .continuous)
                .frame(width: width, height: height)
                .foregroundColor(Color.black.opacity(0.1))
            
            RoundedRectangle(cornerSize: CGSize(width: 20, height: 10), style: .continuous).frame(width: percent * multiplier, height: 20).background(
                LinearGradient(gradient: Gradient(colors: [color1, color2]), startPoint: /*@START_MENU_TOKEN@*/.leading/*@END_MENU_TOKEN@*/, endPoint: /*@START_MENU_TOKEN@*/.trailing/*@END_MENU_TOKEN@*/).clipShape(RoundedRectangle(cornerRadius: height))
            ).foregroundColor(.clear)
        }
    }
}

#Preview {
    ProgressBar()
}
