import SwiftUI
import TrainingKit

struct AdherenceCalendarView: View {
    struct EditedDay: Identifiable {
        let date: Date
        var id: Date { date }
    }

    @Environment(AdherenceStore.self) private var store
    @Environment(\.calendar) private var calendar
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon
    @State private var track: AdherenceTrack = .general
    @State private var year = Calendar.current.component(.year, from: .now)
    @State private var edited: EditedDay?
    @State private var edge: Edge = .trailing

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if profile.adherenceTracks.count > 1 {
                        Picker("Track", selection: animatedSwitch($track, among: profile.adherenceTracks, edge: $edge)) {
                            ForEach(profile.adherenceTracks, id: \.self) { track in
                                Text(track.title).tag(track)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    yearSwitcher
                    VStack(alignment: .leading, spacing: 14) {
                        summary
                        grid
                    }
                    .id(track)
                    .switchTransition(edge: edge)
                    .swipeToSwitch($track, among: profile.adherenceTracks, edge: $edge)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .onAppear {
                if !profile.adherenceTracks.contains(track) {
                    track = .general
                }
                proxy.scrollTo(calendar.monday(of: .now), anchor: .center)
            }
        }
        .background { ConsoleBackground() }
        .navigationTitle("Adherence calendar")
        .sheet(item: $edited) { day in
            DayMarkSheet(track: track, date: day.date)
                .presentationDetents([.medium, .large])
        }
    }

    private var yearSwitcher: some View {
        HStack {
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Previous year"))
            Spacer()
            Text(String(year))
                .font(.system(.title3, design: .monospaced, weight: .bold))
                .foregroundStyle(Palette.text)
            Spacer()
            Button {
                year += 1
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text("Next year"))
        }
    }

    private var summary: some View {
        let counts = store.book.counts(track, year: year)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { summaryItems(counts) }
            VStack(alignment: .leading, spacing: 6) { summaryItems(counts) }
        }
    }

    @ViewBuilder
    private func summaryItems(_ counts: [AdherenceStatus: Int]) -> some View {
        ForEach(AdherenceStatus.allCases, id: \.self) { status in
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                Text(status.title)
                    .font(.caption)
                    .foregroundStyle(Palette.text.opacity(0.85))
                Text(counts[status] ?? 0, format: .number)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(status.color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05), in: Capsule())
        }
    }

    private var grid: some View {
        let weeks = YearGrid.weeks(year: year, calendar: calendar)
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    Text(weekdaySymbol(day))
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(weeks, id: \.self) { week in
                if let month = week.startsMonth {
                    Text(month, format: .dateTime.month(.wide))
                        .consoleLabel()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                HStack(spacing: 4) {
                    ForEach(week.cells, id: \.self) { cell in
                        DayCell(cell: cell, mark: store.book.mark(track, on: cell.date, calendar: calendar)) {
                            edited = EditedDay(date: cell.date)
                        }
                    }
                }
                .id(week.cells.first?.date)
            }
        }
        .padding(14)
        .consoleCard()
    }

    private func weekdaySymbol(_ day: Int) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return symbols[(day + 1) % 7]
    }
}

private struct DayCell: View {
    let cell: CalendarWeek.Cell
    let mark: DayMark?
    let action: () -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        let isToday = calendar.isDateInToday(cell.date)
        Button(action: action) {
            Text(calendar.component(.day, from: cell.date), format: .number)
                .font(.system(.caption, design: .monospaced, weight: isToday ? .bold : .regular))
                .foregroundStyle(mark == nil ? Palette.text.opacity(0.7) : Palette.background)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(mark?.status.color ?? Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    if isToday {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Palette.fitness, lineWidth: 1.5)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let mark, !mark.comment.isEmpty {
                        Circle()
                            .fill(Palette.background)
                            .frame(width: 5, height: 5)
                            .padding(4)
                    }
                }
        }
        .buttonStyle(.plain)
        .opacity(cell.isInYear ? 1 : 0.25)
        .disabled(!cell.isInYear)
        .accessibilityLabel(Text(cell.date, format: .dateTime.day().month(.wide)))
        .accessibilityValue(mark.map { Text($0.status.title) } ?? Text("No mark"))
    }
}

struct DayMarkSheet: View {
    let track: AdherenceTrack
    let date: Date

    @Environment(AdherenceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @State private var status: AdherenceStatus?
    @State private var comment = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AdherenceStatus.allCases, id: \.self) { item in
                        Button {
                            status = item
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .foregroundStyle(item.color)
                                    .font(.title3)
                                Text(item.title)
                                    .foregroundStyle(Palette.text)
                                Spacer()
                                if status == item {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Palette.fitness)
                                }
                            }
                        }
                        .accessibilityAddTraits(status == item ? .isSelected : [])
                    }
                } header: {
                    Text(track.title)
                        .consoleLabel()
                }
                .listRowBackground(Palette.surface)

                Section {
                    TextField("Comment", text: $comment, axis: .vertical)
                        .lineLimit(2...4)
                }
                .listRowBackground(Palette.surface)

                if store.book.mark(track, on: date, calendar: calendar) != nil {
                    Section {
                        Button("Remove mark", role: .destructive) {
                            store.perform { $0.setMark(nil, track, on: date, calendar: calendar) }
                            dismiss()
                        }
                    }
                    .listRowBackground(Palette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        if let status {
                            store.perform { $0.setMark(DayMark(status: status, comment: comment), track, on: date, calendar: calendar) }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                let mark = store.book.mark(track, on: date, calendar: calendar)
                status = mark?.status
                comment = mark?.comment ?? ""
            }
        }
    }
}

extension AdherenceStatus {
    var title: LocalizedStringResource {
        switch self {
        case .full: "Done"
        case .partial: "Partly done"
        case .missed: "Missed"
        }
    }

    var symbol: String {
        switch self {
        case .full: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .missed: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .full: Palette.success
        case .partial: Palette.warning
        case .missed: Palette.danger
        }
    }
}

extension AdherenceTrack {
    var title: LocalizedStringResource {
        switch self {
        case .general: "General"
        case .swim: "Swim"
        case .bike: "Bike"
        case .run: "Run"
        }
    }
}
