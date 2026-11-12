import SwiftUI

private enum PreferenceKey {
    static let theme = "planner.appearance.theme"
    static let rowSize = "planner.appearance.rowSize"
    static let firstWeekday = "planner.calendar.firstWeekday"
    static let clock = "planner.calendar.clock"
}

private enum Theme: String {
    case system, light, dark

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private enum RowSize: String {
    case system, compact, spacious

    func minimumHeight(default height: CGFloat) -> CGFloat {
        switch self {
        case .system: height
        case .compact: 20
        case .spacious: 42
        }
    }
}

private enum Clock: String {
    case system, twelveHour, twentyFourHour

    func locale(from systemLocale: Locale) -> Locale {
        guard self != .system else { return systemLocale }
        var components = Locale.Components(locale: systemLocale)
        components.hourCycle = self == .twelveHour ? .oneToTwelve : .zeroToTwentyThree
        return Locale(components: components)
    }
}

struct GeneralPreferencesView: View {
    @AppStorage(PreferenceKey.theme) private var theme = Theme.system
    @AppStorage(PreferenceKey.rowSize) private var rowSize = RowSize.system
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday = 0
    @AppStorage(PreferenceKey.clock) private var clock = Clock.system
    @Environment(\.calendar) private var calendar

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    Text("System").tag(Theme.system)
                    Text("Light").tag(Theme.light)
                    Text("Dark").tag(Theme.dark)
                }
                Picker("Item spacing", selection: $rowSize) {
                    Text("System").tag(RowSize.system)
                    Text("Compact").tag(RowSize.compact)
                    Text("Spacious").tag(RowSize.spacious)
                }
            }
            Section("Dates and times") {
                Picker("First day of week", selection: $firstWeekday) {
                    Text("System").tag(0)
                    ForEach(Array(calendar.standaloneWeekdaySymbols.enumerated()), id: \.offset) { offset, name in
                        Text(name).tag(offset + 1)
                    }
                }
                Picker("Time display", selection: $clock) {
                    Text("System").tag(Clock.system)
                    Text("12-hour").tag(Clock.twelveHour)
                    Text("24-hour").tag(Clock.twentyFourHour)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct PlannerPreferencesModifier: ViewModifier {
    @AppStorage(PreferenceKey.theme) private var theme = Theme.system
    @AppStorage(PreferenceKey.rowSize) private var rowSize = RowSize.system
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday = 0
    @AppStorage(PreferenceKey.clock) private var clock = Clock.system
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar
    @Environment(\.defaultMinListRowHeight) private var defaultRowHeight

    func body(content: Content) -> some View {
        var displayedCalendar = calendar
        if (1...7).contains(firstWeekday) { displayedCalendar.firstWeekday = firstWeekday }
        return content
            .preferredColorScheme(theme.scheme)
            .environment(\.defaultMinListRowHeight, rowSize.minimumHeight(default: defaultRowHeight))
            .environment(\.locale, clock.locale(from: locale))
            .environment(\.calendar, displayedCalendar)
    }
}
