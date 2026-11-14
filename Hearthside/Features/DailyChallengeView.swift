import SwiftUI
import HearthsideCore

/// Monthly calendar of daily deals. Today is free; missed days of this month can be
/// caught up with a rewarded ad. A full month earns a village decoration.
struct DailyChallengeView: View {
    @Environment(AppModel.self) private var app
    @State private var catchUpDay: DayKey?

    var body: some View {
        let today = app.today
        let daily = app.progress.daily
        let first = today.firstOfMonth
        let leading = first.isoWeekday - 1
        let days = (0..<today.daysInMonth).map { first.adding(days: $0) }

        ScrollView {
            VStack(spacing: 18) {
                Panel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(first.date, format: .dateTime.month(.wide).year())
                            .font(AppFont.nunito(.title2, weight: .bold))
                        Text("daily.progress \(daily.completedCount(inMonthOf: today)) \(today.daysInMonth)")
                            .font(AppFont.nunito(.subheadline))
                        ProgressView(value: Double(daily.completedCount(inMonthOf: today)), total: Double(today.daysInMonth))
                            .tint(Color.pine)
                        Label {
                            Text("daily.reward \(String(localized: String.LocalizationValue(Decoration.forMonth(today.monthKey).nameKey)))")
                        } icon: {
                            Image(systemName: "gift.fill").foregroundStyle(Color.hearthRed)
                        }
                        .font(AppFont.nunito(.subheadline, weight: .semibold))
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol).font(AppFont.nunito(.caption, weight: .bold)).foregroundStyle(Color.cream.opacity(0.7))
                    }
                    ForEach(0..<leading, id: \.self) { _ in Color.clear.frame(height: 48) }
                    ForEach(days, id: \.self) { day in
                        dayCell(day, today: today, daily: daily)
                    }
                }

                Button {
                    app.playDaily(today)
                } label: {
                    Label(LocalizedStringKey(daily.isCompleted(today) ? "daily.replay" : "daily.playtoday"), systemImage: "play.fill")
                }
                .buttonStyle(HearthButtonStyle(color: .pine))

                Text("daily.rules").font(AppFont.nunito(.footnote)).foregroundStyle(Color.cream.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(16)
        }
        .background(HearthBackground())
        .navigationTitle(Text("daily.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("daily.catchup.title", isPresented: Binding(get: { catchUpDay != nil }, set: { if !$0 { catchUpDay = nil } })) {
            if app.ads.rewardedAvailable, let day = catchUpDay {
                Button("daily.catchup.watch") { Task { await app.catchUpDaily(day) } }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(LocalizedStringKey(app.ads.rewardedAvailable ? "daily.catchup.message" : "hint.extra.unavailable"))
        }
    }

    private var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let symbols = calendar.veryShortWeekdaySymbols
        return Array(symbols[1...] + symbols[..<1]) // Monday first
    }

    private func dayCell(_ day: DayKey, today: DayKey, daily: DailyChallengeState) -> some View {
        let done = daily.isCompleted(day)
        let isToday = day == today
        let future = day > today
        return Button {
            if isToday || done {
                app.playDaily(day)
            } else if daily.needsCatchUp(day, today: today) {
                catchUpDay = day
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(done ? Color.pine : (isToday ? Color.honey : Color.black.opacity(future ? 0.1 : 0.25)))
                if done {
                    Image(systemName: "checkmark").font(.headline.bold()).foregroundStyle(Color.cream)
                } else {
                    Text("\(day.day)").font(AppFont.nunito(.headline, weight: .bold))
                        .foregroundStyle(isToday ? Color.ink : Color.cream.opacity(future ? 0.35 : 0.9))
                }
            }
            .frame(height: 48)
        }
        .disabled(future)
        .accessibilityLabel(Text(day.date, format: .dateTime.day().month(.wide)))
        .accessibilityValue(Text(LocalizedStringKey(done ? "daily.done" : (isToday ? "daily.today" : "daily.open"))))
    }
}
