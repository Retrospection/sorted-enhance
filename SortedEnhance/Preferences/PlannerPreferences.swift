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

struct PlannerSettingsView: View {
    @ObservedObject var recovery: PlannerRecovery
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "gearshape")
                Text("Settings").font(.system(size: 19, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            ScrollView {
                VStack(spacing: 36) {
                    GeneralPreferencesView()
                    RecoveryView(recovery: recovery)
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        SettingsSection("About") {
                            SettingsRow("Version", icon: "info.circle", color: .gray) {
                                Text(verbatim: version)
                            }
                        }
                    }
                }
                .padding(.top, 28)
                .padding(.bottom, 30)
            }
        }
        .frame(width: 620, height: 680)
        .foregroundStyle(.white)
        .background(Color(red: 0.153, green: 0.204, blue: 0.267))
        .environment(\.colorScheme, .dark)
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 16)
                .padding(.bottom, 7)
                .accessibilityAddTraits(.isHeader)
            Divider()
            content
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: Text
    let icon: String
    let color: Color
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.init(title: Text(title), icon: icon, color: color, content: content)
    }

    init(title: Text, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 29, height: 29)
                    .background(color, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
                title.font(.system(size: 15, weight: .semibold))
                Spacer()
                content
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            Divider().padding(.leading, 53)
        }
        .contentShape(Rectangle())
    }
}

struct GeneralPreferencesView: View {
    @AppStorage(PreferenceKey.theme) private var theme = Theme.system
    @AppStorage(PreferenceKey.rowSize) private var rowSize = RowSize.system
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday = 2
    @AppStorage(PreferenceKey.clock) private var clock = Clock.system
    @Environment(\.calendar) private var calendar

    var body: some View {
        SettingsSection("Appearance") {
            SettingsRow("Theme", icon: "circle.lefthalf.filled", color: .indigo) {
                Picker("Theme", selection: $theme) {
                    Text("System").tag(Theme.system)
                    Text("Light").tag(Theme.light)
                    Text("Dark").tag(Theme.dark)
                }
            }
            SettingsRow("Item spacing", icon: "text.line.first.and.arrowtriangle.forward", color: .blue) {
                Picker("Item spacing", selection: $rowSize) {
                    Text("System").tag(RowSize.system)
                    Text("Compact").tag(RowSize.compact)
                    Text("Spacious").tag(RowSize.spacious)
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .buttonStyle(.borderless)

        SettingsSection("Dates and times") {
            SettingsRow("First day of week", icon: "calendar", color: .red) {
                Picker("First day of week", selection: $firstWeekday) {
                    Text("System").tag(0)
                    ForEach(Array(calendar.standaloneWeekdaySymbols.enumerated()), id: \.offset) { offset, name in
                        Text(name).tag(offset + 1)
                    }
                }
            }
            SettingsRow("Time display", icon: "clock", color: .orange) {
                Picker("Time display", selection: $clock) {
                    Text("System").tag(Clock.system)
                    Text("12-hour").tag(Clock.twelveHour)
                    Text("24-hour").tag(Clock.twentyFourHour)
                }
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .buttonStyle(.borderless)
    }
}

struct PlannerPreferencesModifier: ViewModifier {
    @AppStorage(PreferenceKey.theme) private var theme = Theme.system
    @AppStorage(PreferenceKey.rowSize) private var rowSize = RowSize.system
    @AppStorage(PreferenceKey.firstWeekday) private var firstWeekday = 2
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
