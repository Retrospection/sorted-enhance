import SwiftUI

enum PlannerSection: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case schedule = "Schedule"
    case lists = "Lists"
    case tags = "Tags"
    case history = "History"
    case trash = "Trash"

    var id: Self { self }
    var accessibilityID: String { rawValue }
    var label: LocalizedStringKey { LocalizedStringKey(rawValue) }

    var tint: Color {
        switch self {
        case .inbox: Color(red: 0, green: 139 / 255, blue: 250 / 255)
        case .schedule: Color(red: 1, green: 45 / 255, blue: 85 / 255)
        case .lists: Color(red: 25 / 255, green: 169 / 255, blue: 1)
        case .tags: Color(red: 41 / 255, green: 183 / 255, blue: 52 / 255)
        case .history: Color(red: 250 / 255, green: 118 / 255, blue: 88 / 255)
        case .trash: Color(red: 140 / 255, green: 168 / 255, blue: 212 / 255)
        }
    }

    var systemImage: String {
        switch self {
        case .inbox: "tray.full"
        case .schedule: "calendar"
        case .lists: "list.bullet.rectangle"
        case .tags: "tag"
        case .history: "checkmark.square"
        case .trash: "trash"
        }
    }
}

struct PlannerSidebar: View {
    @Binding var section: PlannerSection
    @Binding var day: Date
    let onSettings: () -> Void
    let onHelp: () -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var browsingMonth: Date?
    @FocusState private var focusedDate: Date?

    private let background = Color(red: 39 / 255, green: 52 / 255, blue: 68 / 255)
    private let secondary = Color(red: 159 / 255, green: 179 / 255, blue: 200 / 255)
    private let selection = Color(red: 0.39, green: 0.75, blue: 1)

    private var month: Date { browsingMonth ?? day }

    private var weekdaySymbols: [String] {
        var localized = calendar
        localized.locale = locale
        return localized.shortStandaloneWeekdaySymbols
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        monthCalendar
                        divider
                        navigation
                    }
                }
                .scrollIndicators(.hidden)
                footer
            }
            .frame(width: geometry.size.width)
        }
        .background(background.ignoresSafeArea())
        .foregroundStyle(.white)
        .onChange(of: day) { _, newDate in
            browsingMonth = calendar.dateInterval(of: .month, for: newDate)?.start
        }
    }

    private var monthCalendar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: locale.language.languageCode?.identifier == "zh" ? 0 : 4) {
                    Text(month, format: .dateTime.year().locale(locale))
                        .fontWeight(.regular)
                        .foregroundStyle(section.tint)
                    Text(month, format: .dateTime.month(.wide).locale(locale))
                        .fontWeight(.semibold)
                }
                Spacer(minLength: 0)
                monthButton(by: -1)
                monthButton(by: 1)
            }
            .font(.system(size: 24, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.top, 34)

            let weekdays = weekdaySymbols
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { offset in
                    Text(verbatim: weekdays[(calendar.firstWeekday - 1 + offset) % 7])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 6)
            .accessibilityHidden(true)

            let dates = SidebarMonth.dates(containing: month, calendar: calendar)
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(0..<(dates.count / 7), id: \.self) { week in
                    GridRow {
                        ForEach(dates[week * 7..<(week + 1) * 7], id: \.self) { date in
                            dayButton(date)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 365)
    }

    private func monthButton(by offset: Int) -> some View {
        Button {
            guard let start = calendar.dateInterval(of: .month, for: month)?.start else { return }
            browsingMonth = calendar.date(byAdding: .month, value: offset, to: start)
        } label: {
            Image(systemName: offset < 0 ? "chevron.backward" : "chevron.forward")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondary)
                .frame(width: 25, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(offset < 0 ? Text("Previous month") : Text("Next month"))
        .accessibilityIdentifier(offset < 0 ? "PreviousMonth" : "NextMonth")
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: day)
        let outside = !calendar.isDate(date, equalTo: month, toGranularity: .month)
        let past = date < calendar.startOfDay(for: .now)
        return Button {
            select(date)
        } label: {
            HStack(spacing: 1) {
                Text(calendar.component(.day, from: date), format: .number.locale(locale))
                    .font(.system(size: 14, weight: .bold))
                if locale.language.languageCode?.identifier == "zh" {
                    let lunarDay = SidebarMonth.lunarDay(date, timeZone: calendar.timeZone)
                    VStack(spacing: 0) {
                        ForEach(Array(lunarDay.enumerated()), id: \.offset) { _, character in
                            Text(verbatim: String(character))
                        }
                    }
                    .font(.system(size: 6.5))
                }
            }
            .foregroundStyle(selected ? selection : (outside || past ? secondary : .white))
            .opacity(outside && !selected ? 0.54 : 1)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(selection.opacity(0.2))
                        .padding(.horizontal, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focusedDate, equals: date)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { key in
            let offset: Int
            switch key.key {
            case .leftArrow: offset = layoutDirection == .rightToLeft ? 1 : -1
            case .rightArrow: offset = layoutDirection == .rightToLeft ? -1 : 1
            case .upArrow: offset = -7
            case .downArrow: offset = 7
            default: return .ignored
            }
            guard let next = calendar.date(byAdding: .day, value: offset, to: date) else { return .ignored }
            select(next)
            focusedDate = next
            return .handled
        }
        .accessibilityLabel(Text(date, format: .dateTime.year().month(.wide).day().weekday(.wide)))
        .accessibilityIdentifier(SidebarMonth.dayIdentifier(date, timeZone: calendar.timeZone))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func select(_ date: Date) {
        day = calendar.startOfDay(for: date)
        browsingMonth = day
        section = .schedule
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
    }

    private var navigation: some View {
        VStack(spacing: 0) {
            ForEach(PlannerSection.allCases) { destination in
                if destination == .history {
                    divider.padding(.vertical, 5)
                }
                Button {
                    section = destination
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: destination.systemImage)
                            .symbolVariant(.none)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(section == destination ? .white : secondary)
                            .frame(width: 35, height: 35)
                            .background {
                                if section == destination {
                                    RoundedRectangle(cornerRadius: 8).fill(destination.tint)
                                }
                            }
                        Text(destination.label)
                            .foregroundStyle(section == destination ? .white : secondary)
                            .lineLimit(1)
                            .font(.system(size: 16, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 5)
                    .frame(height: 43)
                    .background {
                        if section == destination {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 51 / 255, green: 70 / 255, blue: 95 / 255))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .frame(height: 53)
                .accessibilityIdentifier(destination.accessibilityID)
                .accessibilityAddTraits(section == destination ? .isSelected : [])
            }
        }
        .padding(.vertical, 5)
    }

    private var footer: some View {
        HStack {
            Button(action: onSettings) {
                Image(systemName: "gearshape").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Settings")
            .help("Settings")
            Spacer()
            Button(action: onHelp) {
                Image(systemName: "questionmark.circle").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Help")
            .help("Help")
        }
        .font(.system(size: 18))
        .foregroundStyle(secondary)
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

enum SidebarMonth {
    static func dayIdentifier(_ date: Date, timeZone: TimeZone) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "SidebarDay-%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func dates(containing day: Date, calendar: Calendar) -> [Date] {
        guard let start = calendar.dateInterval(of: .month, for: day)?.start,
              let first = calendar.dateInterval(of: .weekOfYear, for: start)?.start else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    static func lunarDay(_ date: Date, timeZone: TimeZone) -> String {
        var lunar = Calendar(identifier: .chinese)
        lunar.timeZone = timeZone
        let date = lunar.component(.day, from: date)
        let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        switch date {
        case 1...9: return "初" + digits[date]
        case 10: return "初十"
        case 11...19: return "十" + digits[date - 10]
        case 20: return "二十"
        case 21...29: return "廿" + digits[date - 20]
        case 30: return "三十"
        default: return ""
        }
    }
}
