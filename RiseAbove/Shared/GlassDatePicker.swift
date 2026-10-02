import SwiftUI

struct GlassDatePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: Date
    var range: PartialRangeThrough<Date> = ...Date.now

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                Text(selection, format: .dateTime.day().month(.wide).year())
                    .monospacedDigit()
            }
        }
        .buttonStyle(.consoleChip(isActive: true))
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(selection, format: .dateTime.day().month(.wide).year()))
        .popover(isPresented: $isPresented) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .consoleLabel()
                    .padding(.horizontal, 8)
                DatePicker(title, selection: $selection, in: range, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Palette.fitness)
            }
            .padding(16)
            .frame(width: 340)
            .presentationCompactAdaptation(.popover)
        }
    }
}
