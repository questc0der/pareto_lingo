import WidgetKit
import SwiftUI

private let appGroupId = "group.com.example.pareto_lingo"

struct ParetoWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let reminderEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int
    let languageFlag: String
}

struct ParetoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParetoWidgetEntry {
        ParetoWidgetEntry(
            date: Date(),
            streak: 0,
            reminderEnabled: false,
            reminderHour: 20,
            reminderMinute: 0,
            languageFlag: "EN"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ParetoWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParetoWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> ParetoWidgetEntry {
        let defaults = UserDefaults(suiteName: appGroupId)

        let streak = defaults?.integer(forKey: "pl_streak") ?? 0
        let reminderEnabled = defaults?.bool(forKey: "pl_reminder_enabled") ?? false
        let reminderHour = defaults?.integer(forKey: "pl_reminder_hour") ?? 20
        let reminderMinute = defaults?.integer(forKey: "pl_reminder_minute") ?? 0
        let languageFlag = defaults?.string(forKey: "pl_language_flag") ?? "EN"

        return ParetoWidgetEntry(
            date: Date(),
            streak: streak,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            languageFlag: languageFlag
        )
    }
}

struct ParetoLingoHomeWidgetEntryView: View {
    var entry: ParetoWidgetProvider.Entry

    private var reminderText: String {
        if !entry.reminderEnabled {
            return "Reminder Off"
        }

        let hour = String(format: "%02d", entry.reminderHour)
        let minute = String(format: "%02d", entry.reminderMinute)
        return "Reminder \(hour):\(minute)"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.16, blue: 0.29), Color(red: 0.17, green: 0.11, blue: 0.27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Pareto Lingo")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))

                HStack {
                    Text(entry.languageFlag)
                        .font(.system(size: 24, weight: .bold))
                    Spacer()
                    Text("🔥 \(entry.streak)")
                        .font(.headline)
                }
                .foregroundStyle(.white)

                Text(reminderText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
    }
}

struct ParetoLingoHomeWidget: Widget {
    let kind: String = "ParetoLingoHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParetoWidgetProvider()) { entry in
            ParetoLingoHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pareto Daily")
        .description("Shows your current streak and reminder status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    ParetoLingoHomeWidget()
} timeline: {
    ParetoWidgetEntry(
        date: .now,
        streak: 8,
        reminderEnabled: true,
        reminderHour: 20,
        reminderMinute: 30,
        languageFlag: "FR"
    )
}
