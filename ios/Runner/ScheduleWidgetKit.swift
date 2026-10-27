import WidgetKit
import SwiftUI

// MARK: - SPEC-UI-AUDIT-WIDGET-PARITY-01: iOS WidgetKit Implementation
// Supports .systemSmall (2x2), .systemMedium (4x2), .systemLarge (4x4 Weekly Grid 8 Ô), and .accessoryRectangular (Lock Screen)

// MARK: - JSON Codable Models for UserDefaults Payload

struct ClassItemPayload: Codable, Hashable {
    let courseName: String
    let classCode: String
    let timeSlot: String
    let room: String
    let teacher: String
    let isCurrentOrNext: Bool?
    let isFinished: Bool?
    let isExam: Bool?

    enum CodingKeys: String, CodingKey {
        case courseName = "course_name"
        case classCode = "class_code"
        case timeSlot = "time_slot"
        case room
        case teacher
        case isCurrentOrNext = "is_current_or_next"
        case isFinished = "is_finished"
        case isExam = "is_exam"
    }
}

struct DaySchedulePayload: Codable, Hashable {
    let dayLabel: String
    let dateStr: String
    let weekdayStr: String
    let isToday: Bool
    let isDimmed: Bool?
    let classes: [ClassItemPayload]

    enum CodingKeys: String, CodingKey {
        case dayLabel = "day_label"
        case dateStr = "date_str"
        case weekdayStr = "weekday_str"
        case isToday = "is_today"
        case isDimmed = "is_dimmed"
        case classes
    }
}

struct ScheduleDataPayload: Codable {
    let updatedAt: String?
    let widgetTitle: String?
    let widgetSubtitle: String?
    let layoutMode: String?
    let days: [DaySchedulePayload]

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case widgetTitle = "widget_title"
        case widgetSubtitle = "widget_subtitle"
        case layoutMode = "layout_mode"
        case days
    }
}

struct ThemeConfigPayload: Codable {
    let layoutMode: String?
    let bgStyle: String?
    let bgColorHex: String?
    let bgOpacity: Double?
    let textPrimaryHex: String?
    let textSecondaryHex: String?
    let accentColorHex: String?
    let borderColorHex: String?
    let showRoom: Bool?
    let showTime: Bool?
    let showTeacher: Bool?
    let showClassCode: Bool?

    enum CodingKeys: String, CodingKey {
        case layoutMode = "layout_mode"
        case bgStyle = "bg_style"
        case bgColorHex = "bg_color_hex"
        case bgOpacity = "bg_opacity"
        case textPrimaryHex = "text_primary_hex"
        case textSecondaryHex = "text_secondary_hex"
        case accentColorHex = "accent_color_hex"
        case borderColorHex = "border_color_hex"
        case showRoom = "show_room"
        case showTime = "show_time"
        case showTeacher = "show_teacher"
        case showClassCode = "show_class_code"
    }
}

// MARK: - Timeline Entry

struct ScheduleWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let dayLabel: String
    let weekdayStr: String
    let dateStr: String
    let courseName: String
    let classCode: String // e.g. TH4327_23CN 2
    let timeSlot: String
    let room: String
    let showTeacher: Bool
    let showClassCode: Bool
    let isGlass: Bool
    let bgColorHex: String
    let bgOpacity: Double
    let accentColorHex: String
    let primaryColorHex: String
    let secondaryColorHex: String
    let days: [DaySchedulePayload]
    let todayClasses: [ClassItemPayload]
    let isLoggedIn: Bool
}

// MARK: - Timeline Provider Reading UserDefaults(suiteName: "group.vn.edu.hau.tramkien")

struct ScheduleTimelineProvider: TimelineProvider {
    typealias Entry = ScheduleWidgetEntry

    func placeholder(in context: Context) -> ScheduleWidgetEntry {
        ScheduleTimelineProvider.mockEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleWidgetEntry) -> Void) {
        completion(ScheduleTimelineProvider.loadData(for: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleWidgetEntry>) -> Void) {
        let entry = ScheduleTimelineProvider.loadData(for: context.family)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    static func loadData(for family: WidgetFamily) -> ScheduleWidgetEntry {
        let appGroupId = "group.vn.edu.hau.tramkien"
        let userDefaults = UserDefaults(suiteName: appGroupId) ?? UserDefaults.standard

        let specificKey: String
        switch family {
        case .systemSmall:
            specificKey = "widget_schedule_data_single_day"
        case .systemMedium:
            specificKey = "widget_schedule_data_three_days"
        case .systemLarge:
            specificKey = "widget_schedule_data_seven_days"
        case .accessoryRectangular:
            specificKey = "widget_schedule_data_single_day"
        @unknown default:
            specificKey = "widget_schedule_data"
        }

        func readString(key: String) -> String? {
            userDefaults.string(forKey: key) ??
            userDefaults.string(forKey: "flutter." + key) ??
            UserDefaults.standard.string(forKey: key) ??
            UserDefaults.standard.string(forKey: "flutter." + key)
        }

        let scheduleJsonStr = readString(key: specificKey) ?? readString(key: "widget_schedule_data")
        let themeJsonStr = readString(key: "widget_theme_config")

        var scheduleData: ScheduleDataPayload? = nil
        if let jsonStr = scheduleJsonStr, let data = jsonStr.data(using: .utf8) {
            scheduleData = try? JSONDecoder().decode(ScheduleDataPayload.self, from: data)
        }

        var themeConfig: ThemeConfigPayload? = nil
        if let jsonStr = themeJsonStr, let data = jsonStr.data(using: .utf8) {
            themeConfig = try? JSONDecoder().decode(ThemeConfigPayload.self, from: data)
        }

        let days = scheduleData?.days ?? []
        let todayDay = days.first(where: { $0.isToday }) ?? days.first
        let todayClasses = todayDay?.classes ?? []
        let firstClass = todayClasses.first

        let isGlass = (themeConfig?.bgStyle == "system_glass" || themeConfig?.bgStyle == "frosted_glass")
        let isLoggedIn = (scheduleData != nil && !days.isEmpty)

        let widgetTitle: String
        let widgetSubtitle: String
        if !isLoggedIn {
            widgetTitle = "Trạm Kiến"
            widgetSubtitle = ""
        } else {
            widgetTitle = scheduleData?.widgetTitle ?? (family == .systemLarge ? "LỊCH TUẦN" : "LỊCH HỌC")
            widgetSubtitle = scheduleData?.widgetSubtitle ?? todayDay?.dateStr ?? ""
        }

        return ScheduleWidgetEntry(
            date: Date(),
            title: widgetTitle,
            subtitle: widgetSubtitle,
            dayLabel: todayDay?.dayLabel ?? "HÔM NAY",
            weekdayStr: todayDay?.weekdayStr ?? "T2",
            dateStr: todayDay?.dateStr ?? "",
            courseName: firstClass?.courseName ?? "",
            classCode: firstClass?.classCode ?? "",
            timeSlot: firstClass?.timeSlot ?? "",
            room: firstClass?.room ?? "",
            showTeacher: themeConfig?.showTeacher ?? false,
            showClassCode: themeConfig?.showClassCode ?? false,
            isGlass: isGlass,
            bgColorHex: themeConfig?.bgColorHex ?? "#1C1C1E",
            bgOpacity: themeConfig?.bgOpacity ?? 0.85,
            accentColorHex: themeConfig?.accentColorHex ?? "#1D64F2",
            primaryColorHex: themeConfig?.textPrimaryHex ?? "#FFFFFF",
            secondaryColorHex: themeConfig?.textSecondaryHex ?? "#98989D",
            days: days,
            todayClasses: todayClasses,
            isLoggedIn: isLoggedIn
        )
    }

    static func mockEntry() -> ScheduleWidgetEntry {
        ScheduleWidgetEntry(
            date: Date(),
            title: "LỊCH HỌC",
            subtitle: "Hôm nay",
            dayLabel: "HÔM NAY",
            weekdayStr: "T2",
            dateStr: "20/10",
            courseName: "Lập trình thiết bị di động",
            classCode: "TH4327_23CN 2",
            timeSlot: "07:00 - 09:25",
            room: "P.H302",
            showTeacher: false,
            showClassCode: false,
            isGlass: true,
            bgColorHex: "#1C1C1E",
            bgOpacity: 0.85,
            accentColorHex: "#1D64F2",
            primaryColorHex: "#FFFFFF",
            secondaryColorHex: "#98989D",
            days: [],
            todayClasses: [],
            isLoggedIn: true
        )
    }
}

// MARK: - Widget Views

func formatStartTime(_ timeSlot: String) -> String {
    let raw = timeSlot.components(separatedBy: CharacterSet(charactersIn: "–-")).first?.trimmingCharacters(in: .whitespaces) ?? ""
    if raw.isEmpty { return "" }
    let firstToken = raw.components(separatedBy: " ").first?.trimmingCharacters(in: .whitespaces) ?? ""
    if firstToken.contains(":") {
        let parts = firstToken.components(separatedBy: ":")
        if let h = Int(parts[0].trimmingCharacters(in: .whitespaces)) {
            let m = parts.count > 1 ? Int(parts[1].trimmingCharacters(in: .whitespaces)) : nil
            if h == 6 && m == 55 { return "7h" }
            if h == 12 && m == 55 { return "12h45" }
            if let m = m, m > 0 {
                return "\(h)h\(String(format: "%02d", m))"
            } else {
                return "\(h)h"
            }
        }
    }
    if firstToken.lowercased().hasSuffix("h") {
        let numPart = String(firstToken.dropLast())
        if let h = Int(numPart) {
            return "\(h)h"
        }
        return firstToken
    }
    if let h = Int(firstToken) {
        return "\(h)h"
    }
    return firstToken
}

func extractStartTime(_ timeSlot: String) -> String {
    return formatStartTime(timeSlot)
}

func extractEndTime(_ timeSlot: String) -> String {
    let parts = timeSlot.components(separatedBy: CharacterSet(charactersIn: "–-"))
    if parts.count <= 1 { return "" }
    let raw = parts[1].trimmingCharacters(in: .whitespaces)
    if raw.isEmpty { return "" }
    let firstToken = raw.components(separatedBy: " ").first?.trimmingCharacters(in: .whitespaces) ?? ""
    if firstToken.isEmpty { return "" }
    var formatted = firstToken
    if firstToken.contains(":") {
        let colonParts = firstToken.components(separatedBy: ":")
        if let h = Int(colonParts[0].trimmingCharacters(in: .whitespaces)) {
            let m = colonParts.count > 1 ? Int(colonParts[1].trimmingCharacters(in: .whitespaces)) : nil
            if let m = m, m > 0 {
                formatted = "\(h)h\(String(format: "%02d", m))"
            } else {
                formatted = "\(h)h"
            }
        }
    } else if firstToken.lowercased().hasSuffix("h") {
        let numPart = String(firstToken.dropLast())
        if let h = Int(numPart) {
            formatted = "\(h)h"
        }
    } else if let h = Int(firstToken) {
        formatted = "\(h)h"
    }
    return formatted.isEmpty ? "" : "- \(formatted)"
}

struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ScheduleWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // Lock Screen Compliance (Vibrancy, 2-line layout, Zero AI Filler)
            VStack(alignment: .leading, spacing: 2) {
                if !entry.isLoggedIn {
                    Text("Trạm Kiến")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Text("Trạm Kiến • Vui lòng đăng nhập")
                        .font(.system(size: 10, weight: .regular))
                        .lineLimit(1)
                } else {
                    Text("\(entry.weekdayStr), \(entry.dateStr) • \(entry.courseName.isEmpty ? "Không có ca học" : "1 ca học \(entry.dayLabel)")")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    if !entry.courseName.isEmpty {
                        Text("\(entry.timeSlot.split(separator: " ").first ?? "")  \(entry.room) • \(entry.courseName.uppercased())")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    } else {
                        Text("Không có ca học")
                            .font(.system(size: 10, weight: .regular))
                    }
                }
            }
            .widgetAccentable()

        case .systemSmall:
            // 2x2 Compact Today View
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Capsule()
                        .fill(Color(hex: entry.accentColorHex) ?? .blue)
                        .frame(width: 3, height: 12)
                    Text(entry.title.isEmpty ? "LỊCH HÔM NAY" : entry.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                if !entry.isLoggedIn {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Trạm Kiến • Vui lòng đăng nhập")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    Spacer()
                } else {
                    let displayClasses = entry.todayClasses.isEmpty
                        ? (entry.courseName.isEmpty ? [] : [ClassItemPayload(courseName: entry.courseName, classCode: entry.classCode, timeSlot: entry.timeSlot, room: entry.room, teacher: "", isCurrentOrNext: true, isFinished: false, isExam: false)])
                        : entry.todayClasses

                    let allFinished = !displayClasses.isEmpty && displayClasses.allSatisfy { $0.isFinished == true }

                    if displayClasses.isEmpty {
                        Spacer()
                        Text("Hôm nay nghỉ")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(displayClasses.prefix(2).enumerated()), id: \.offset) { _, c in
                                let isFinished = c.isFinished == true
                                let isExam = (c.isExam == true || c.courseName.hasPrefix("[THI]"))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(c.courseName)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(isExam ? .red : (isFinished ? .gray : .white))
                                        .lineLimit(1)
                                    let subInfo = [
                                        c.timeSlot,
                                        c.room,
                                        (entry.showTeacher && !c.teacher.isEmpty) ? c.teacher : nil
                                    ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
                                    Text(subInfo)
                                        .font(.system(size: 8.5, weight: .medium))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }

                            if allFinished {
                                Text("[ĐÃ XONG]")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            } else if displayClasses.count > 2 {
                                Text("(+\(displayClasses.count - 2) môn nữa)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Color(hex: entry.accentColorHex) ?? .blue)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(10)
            .widgetBackgroundAdaptive(isGlass: entry.isGlass, bgColorHex: entry.bgColorHex, bgOpacity: entry.bgOpacity)

        case .systemLarge:
            // 4x4 Weekly Widget (8 cells: 2 columns x 4 rows)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Capsule()
                        .fill(Color(hex: entry.accentColorHex) ?? .blue)
                        .frame(width: 3, height: 14)
                    Text(entry.title.isEmpty ? "LỊCH TUẦN" : entry.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: entry.primaryColorHex) ?? .white)
                    Spacer()
                    if !entry.subtitle.isEmpty {
                        Text(entry.subtitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
                    }
                }

                if entry.bgOpacity > 0.05 {
                    Divider()
                        .background(Color(hex: entry.secondaryColorHex)?.opacity(0.2) ?? Color.white.opacity(0.2))
                }

                if !entry.isLoggedIn {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Trạm Kiến • Vui lòng đăng nhập")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    Spacer()
                } else {
                    // 2 columns x 4 rows = 8 cells
                    VStack(spacing: 5) {
                        ForEach(0..<4) { row in
                            HStack(spacing: 6) {
                                let leftIndex = row * 2
                                let rightIndex = row * 2 + 1

                                // Ô bên trái (0, 2, 4, 6)
                                if leftIndex < entry.days.count {
                                    DayGridCellView(day: entry.days[leftIndex], accentColor: Color(hex: entry.accentColorHex) ?? .blue, showTeacher: entry.showTeacher)
                                        .themed(primary: Color(hex: entry.primaryColorHex) ?? .white, secondary: Color(hex: entry.secondaryColorHex) ?? .gray, isTransparent: entry.bgOpacity <= 0.05)
                                } else {
                                    Spacer()
                                }

                                // Ô bên phải (1, 3, 5, 7 -> Ô 7 là Ô Tổng Kết Tuần)
                                if rightIndex == 7 {
                                    WeeklySummaryCellView(days: entry.days, accentColor: Color(hex: entry.accentColorHex) ?? .blue)
                                        .themed(primary: Color(hex: entry.primaryColorHex) ?? .white, secondary: Color(hex: entry.secondaryColorHex) ?? .gray)
                                } else if rightIndex < entry.days.count {
                                    DayGridCellView(day: entry.days[rightIndex], accentColor: Color(hex: entry.accentColorHex) ?? .blue, showTeacher: entry.showTeacher)
                                        .themed(primary: Color(hex: entry.primaryColorHex) ?? .white, secondary: Color(hex: entry.secondaryColorHex) ?? .gray, isTransparent: entry.bgOpacity <= 0.05)
                                } else {
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding(10)
            .widgetBackgroundAdaptive(isGlass: entry.isGlass, bgColorHex: entry.bgColorHex, bgOpacity: entry.bgOpacity)

        default:
            // systemMedium (4x2 Timeline Minimalist Layout)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Capsule()
                        .fill(Color(hex: entry.accentColorHex) ?? .blue)
                        .frame(width: 3, height: 14)
                    Text(entry.title.isEmpty ? "LỊCH HỌC" : entry.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    if !entry.subtitle.isEmpty {
                        Text(entry.subtitle)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.2))

                if !entry.isLoggedIn {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Trạm Kiến • Vui lòng đăng nhập")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    Spacer()
                } else {
                    let displayClasses = entry.todayClasses.isEmpty
                        ? (entry.courseName.isEmpty ? [] : [ClassItemPayload(courseName: entry.courseName, classCode: entry.classCode, timeSlot: entry.timeSlot, room: entry.room, teacher: "", isCurrentOrNext: true, isFinished: false, isExam: false)])
                        : entry.todayClasses

                    let allFinished = !displayClasses.isEmpty && displayClasses.allSatisfy { $0.isFinished == true }

                    if displayClasses.isEmpty {
                        Spacer()
                        Text("Hôm nay nghỉ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(displayClasses.prefix(2).enumerated()), id: \.offset) { _, c in
                                let isExam = (c.isExam == true || c.courseName.hasPrefix("[THI]"))
                                let accent = Color(hex: entry.accentColorHex) ?? .blue
                                HStack(alignment: .center, spacing: 8) {
                                    // Cột trái: Giờ bắt đầu & Giờ kết thúc
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(formatStartTime(c.timeSlot))
                                            .font(.system(size: 12.5, weight: .bold))
                                            .foregroundColor(accent)
                                            .lineLimit(1)
                                        Text(extractEndTime(c.timeSlot))
                                            .font(.system(size: 9.5, weight: .medium))
                                            .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 44, alignment: .leading)

                                    // Trục Timeline: Capsule indicator màu Accent (hoặc đỏ nếu là thi)
                                    Capsule()
                                        .fill(c.isExam == true ? Color.red : (Color(hex: entry.accentColorHex) ?? .blue))
                                        .opacity(1.0)
                                        .frame(width: 3, height: 28)

                                    // Cột phải: Tên môn học + 1 hàng thông tin phụ trợ duy nhất
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.courseName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(isExam ? .red : .white)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            if !c.room.isEmpty && c.room != "-" {
                                                Text(c.room)
                                                    .font(.system(size: 9.5, weight: .medium))
                                                    .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
                                                    .lineLimit(1)
                                            }
                                            if entry.showTeacher && !c.teacher.isEmpty {
                                                Text("• \(c.teacher)")
                                                    .font(.system(size: 9.5, weight: .medium))
                                                    .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
                                                    .lineLimit(1)
                                            }
                                            if entry.showClassCode && !c.classCode.isEmpty {
                                                Text("• \(c.classCode)")
                                                    .font(.system(size: 9.5, weight: .medium))
                                                    .foregroundColor(Color(hex: entry.secondaryColorHex) ?? .gray)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                            Spacer(minLength: 0)
                            if displayClasses.count > 2 {
                                Text("(+\(displayClasses.count - 2) môn nữa)")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundColor(Color(hex: entry.accentColorHex) ?? .blue)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .widgetBackgroundAdaptive(isGlass: entry.isGlass, bgColorHex: entry.bgColorHex, bgOpacity: entry.bgOpacity)
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if entry.isGlass {
            Rectangle()
                .fill(.ultraThinMaterial)
        } else {
            Color(hex: entry.bgColorHex)?.opacity(entry.bgOpacity) ?? Color.black.opacity(entry.bgOpacity)
        }
    }
}

// MARK: - Subviews for Weekly Grid (4x4)

struct DayGridCellView: View {
    let day: DaySchedulePayload
    let accentColor: Color
    var showTeacher: Bool = false
    var primaryColor: Color = .white
    var secondaryColor: Color = .gray
    var isTransparent: Bool = false

    func themed(primary: Color, secondary: Color, isTransparent: Bool) -> DayGridCellView {
        var copy = self
        copy.primaryColor = primary
        copy.secondaryColor = secondary
        copy.isTransparent = isTransparent
        return copy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Text("\(day.weekdayStr) \(day.dateStr)")
                    .font(.system(size: 9.5, weight: day.isToday ? .heavy : .bold))
                    .foregroundColor(day.isToday ? accentColor : secondaryColor)
                if day.isToday {
                    Text("HÔM NAY")
                        .font(.system(size: 6.5, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 0.5)
                        .background(accentColor)
                        .cornerRadius(2.5)
                }
                Spacer()
            }

            if day.classes.isEmpty {
                Text("Không có lịch")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(secondaryColor.opacity(0.8))
                    .lineLimit(1)
            } else {
                let firstClass = day.classes[0]
                let isExam1 = (firstClass.isExam == true || firstClass.courseName.hasPrefix("[THI]"))
                let isFinished1 = firstClass.isFinished == true
                Text(firstClass.courseName)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(isExam1 ? .red : (isFinished1 ? secondaryColor.opacity(0.7) : primaryColor))
                    .lineLimit(1)

                let firstDetails = [
                    firstClass.timeSlot,
                    firstClass.room,
                    (showTeacher && !firstClass.teacher.isEmpty) ? firstClass.teacher : nil
                ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")

                Text(firstDetails)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(secondaryColor)
                    .lineLimit(1)

                if day.classes.count >= 2 {
                    let secondClass = day.classes[1]
                    let isExam2 = (secondClass.isExam == true || secondClass.courseName.hasPrefix("[THI]"))
                    let isFinished2 = secondClass.isFinished == true
                    Text(secondClass.courseName)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(isExam2 ? .red : (isFinished2 ? secondaryColor.opacity(0.7) : primaryColor))
                        .lineLimit(1)

                    if showTeacher && !secondClass.teacher.isEmpty {
                        let secondDetails = [
                            secondClass.timeSlot,
                            secondClass.room,
                            secondClass.teacher
                        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • ")
                        Text(secondDetails)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(secondaryColor)
                            .lineLimit(1)
                    }
                }

                if day.classes.count >= 3 {
                    Text("(+\(day.classes.count - 2) môn nữa)")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(accentColor)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(day.isToday ? accentColor.opacity(0.16) : (isTransparent ? Color.clear : Color.white.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(day.isToday ? accentColor.opacity(0.85) : (isTransparent ? Color.clear : Color.white.opacity(0.08)), lineWidth: day.isToday ? 1.0 : (isTransparent ? 0 : 0.5))
        )
    }
}

struct WeeklySummaryCellView: View {
    let days: [DaySchedulePayload]
    let accentColor: Color
    var primaryColor: Color = .white
    var secondaryColor: Color = .gray

    func themed(primary: Color, secondary: Color) -> WeeklySummaryCellView {
        var copy = self
        copy.primaryColor = primary
        copy.secondaryColor = secondary
        return copy
    }

    var totalClasses: Int {
        days.flatMap { $0.classes }.filter { !($0.isExam == true || $0.courseName.hasPrefix("[THI]")) }.count
    }

    var totalExams: Int {
        days.flatMap { $0.classes }.filter { $0.isExam == true || $0.courseName.hasPrefix("[THI]") }.count
    }

    var emptyDays: Int {
        days.filter { $0.classes.isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("TỔNG KẾT TUẦN")
                .font(.system(size: 9.5, weight: .heavy))
                .foregroundColor(accentColor)

            Text("\(totalClasses) buổi học • \(totalExams) buổi thi")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(primaryColor)
                .lineLimit(1)

            Text("\(emptyDays) ngày trống")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(secondaryColor)

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(accentColor.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(accentColor.opacity(0.5), lineWidth: 0.8)
        )
    }
}

extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if cleanHex.count == 6 {
            cleanHex = "FF" + cleanHex
        }
        guard let val = UInt64(cleanHex, radix: 16) else { return nil }
        let a = Double((val >> 24) & 0xff) / 255.0
        let r = Double((val >> 16) & 0xff) / 255.0
        let g = Double((val >> 8) & 0xff) / 255.0
        let b = Double(val & 0xff) / 255.0
        self.init(.sRGB, red: r, green: blue: b, opacity: a)
    }
}

// MARK: - iOS 17+ Widget Background & Content Margins Parity (SPEC-WIDGET-CORNER-RESIZE-01)

extension View {
    @ViewBuilder
    func widgetBackgroundAdaptive(isGlass: Bool, bgColorHex: String, bgOpacity: Double) -> some View {
        if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            containerBackground(for: .widget) {
                if isGlass {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    Color(hex: bgColorHex)?.opacity(bgOpacity) ?? Color.black.opacity(bgOpacity)
                }
            }
        } else {
            background(
                Group {
                    if isGlass {
                        Rectangle().fill(.ultraThinMaterial)
                    } else {
                        Color(hex: bgColorHex)?.opacity(bgOpacity) ?? Color.black.opacity(bgOpacity)
                    }
                }
            )
        }
    }
}

extension WidgetConfiguration {
    func disableContentMarginsIfNeeded() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 15.0, macOS 12.0, watchOS 9.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}

// MARK: - Widget Definition

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidgetKit"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleTimelineProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .disableContentMarginsIfNeeded()
        .configurationDisplayName("Lịch học Trạm Kiến")
        .description("Xem lịch học HAU nhanh trên màn hình chính và màn hình khóa.")
        .supportedFamilies([
            .systemMedium,
            .systemLarge,
            .accessoryRectangular
        ])
    }
}
