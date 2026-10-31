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

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Snapshot Models

struct SnapshotSessionPayload: Codable {
    let id: Int
    let kind: String // "class" hoặc "exam"
    let subject: String
    let short: String?
    let startMs: Int64
    let endMs: Int64
    let room: String
    let teacher: String?
    let seat: String?
    let color: Int
    let endEstimated: Bool?
}

struct SnapshotPayload: Codable {
    let version: Int
    let generatedAt: Int64
    let tz: String?
    let sessions: [SnapshotSessionPayload]
}

struct Today2x2ViewModel {
    let stateType: String // "noSnapshot", "emptyDay", "allFinished", "sessionActive"
    let statusLabel: String // "Đang học", "Đang thi", "Tiếp theo", "Ngày mai", ""
    let subjectName: String
    let displayTitle: String
    let subInfo: String
    let showProgressBar: Bool
    let progress: Double
    let countdownIos: String?
    let isExam: Bool
    let colorIndex: Int
    let endEstimated: Bool
    let deepLinkUrl: String

    var hasSession: Bool {
        return stateType == "sessionActive"
    }

    static func placeholder() -> Today2x2ViewModel {
        Today2x2ViewModel(
            stateType: "noSnapshot",
            statusLabel: "",
            subjectName: "Đăng nhập để xem lịch",
            displayTitle: "Đăng nhập để xem lịch",
            subInfo: "",
            showProgressBar: false,
            progress: 0.0,
            countdownIos: nil,
            isExam: false,
            colorIndex: 0,
            endEstimated: false,
            deepLinkUrl: "tramkien://schedule"
        )
    }
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: Bước 3 - Month + Today 4x2 Models

struct MonthGridDayPayload: Identifiable {
    var id: String { dateIso }
    let dateIso: String
    let day: Int
    let month: Int
    let year: Int
    let isToday: Bool
    let hasClasses: Bool
    let hasExam: Bool
    let deepLink: String
}

struct MonthTodayCardItemPayload: Identifiable {
    let id: Int
    let timeRoomLine: String
    let displayTitle: String
    let isExam: Bool
    let isCurrent: Bool
    let colorIndex: Int
    let deepLink: String
}

struct MonthToday4x2ViewModel {
    let monthTitle: String
    let weekdayHeaders: [String]
    let cells: [MonthGridDayPayload?]
    let headerLeft: String
    let headerRight: String
    let visibleCards: [MonthTodayCardItemPayload]
    let overflowLabel: String?
    let emptyTitle: String?
    let emptySubtitle: String?

    static func placeholder() -> MonthToday4x2ViewModel {
        MonthToday4x2ViewModel(
            monthTitle: "Tháng --/----",
            weekdayHeaders: ["T2", "T3", "T4", "T5", "T6", "T7", "CN"],
            cells: Array(repeating: nil, count: 42),
            headerLeft: "Hôm nay",
            headerRight: "0 môn",
            visibleCards: [],
            overflowLabel: nil,
            emptyTitle: "Đăng nhập để xem lịch",
            emptySubtitle: ""
        )
    }
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: Bước 4 - Three Days 4x2 Models

struct ThreeDaysCardItemPayload: Identifiable {
    let id: Int
    let timeStr: String
    let roomStr: String
    let timeRoomLine: String
    let shortName: String
    let isExam: Bool
    let isCurrent: Bool
    let colorIndex: Int
    let deepLink: String
}

struct ThreeDaysColumnPayload: Identifiable {
    var id: String { dateIso }
    let dateIso: String
    let title: String
    let isToday: Bool
    let visibleCards: [ThreeDaysCardItemPayload]
    let hiddenCount: Int
    let badgeText: String?
    let isEmpty: Bool
    let emptyText: String
    let deepLink: String
}

struct ThreeDays4x2ViewModel {
    let hasSnapshot: Bool
    let authMessage: String?
    let columns: [ThreeDaysColumnPayload]

    static func placeholder() -> ThreeDays4x2ViewModel {
        ThreeDays4x2ViewModel(
            hasSnapshot: false,
            authMessage: "Đăng nhập để xem lịch",
            columns: []
        )
    }
}

func readSnapshotFromAppGroup() -> SnapshotPayload? {
    guard let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.vn.edu.hau.tramkien") else {
        return nil
    }
    let fileUrl = containerUrl.appendingPathComponent("widget_schedule_snapshot.json")
    guard let data = try? Data(contentsOf: fileUrl) else {
        return nil
    }
    guard let payload = try? JSONDecoder().decode(SnapshotPayload.self, from: data) else {
        return nil
    }
    guard payload.version == 1 else { return nil }
    let maxAgeMs: Int64 = 14 * 24 * 60 * 60 * 1000
    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
    if payload.generatedAt > 0 && (nowMs - payload.generatedAt > maxAgeMs) {
        return nil
    }
    return payload
}

func truncatePreserveSuffixSwift(_ name: String, maxLength: Int) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count <= maxLength { return trimmed }

    let pattern = "(\\s+(?:[0-9]+|[IVXLCDM]+|[A-Za-z]))$"
    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
        if let suffixRange = Range(match.range(at: 1), in: trimmed) {
            let suffix = String(trimmed[suffixRange])
            let budget = maxLength - 1 - suffix.count
            if budget >= 6 {
                let leftBudget = Int(Double(budget) * 0.55)
                let rightBudget = budget - leftBudget
                let leftPart = String(trimmed.prefix(leftBudget)).trimmingCharacters(in: .whitespaces)
                let beforeSuffix = String(trimmed[..<suffixRange.lowerBound])
                let rightPart = String(beforeSuffix.suffix(rightBudget)).trimmingCharacters(in: .whitespaces)
                if !rightPart.isEmpty {
                    return "\(leftPart)…\(rightPart)\(suffix)"
                } else {
                    return "\(leftPart)…\(suffix)"
                }
            }
        }
    }
    let endIndex = trimmed.index(trimmed.startIndex, offsetBy: max(1, maxLength - 1))
    return "\(String(trimmed[..<endIndex]).trimmingCharacters(in: .whitespaces))…"
}

func evaluateToday2x2(snapshot: SnapshotPayload?, at date: Date) -> Today2x2ViewModel {
    var calendar = Calendar(identifier: .gregorian)
    if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        calendar.timeZone = tz
    }

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = calendar.timeZone

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.timeZone = calendar.timeZone

    let todayIso = isoFormatter.string(from: date)
    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    guard let snapshot = snapshot, snapshot.version == 1 else {
        return Today2x2ViewModel(
            stateType: "noSnapshot",
            statusLabel: "",
            subjectName: "Đăng nhập để xem lịch",
            displayTitle: "Đăng nhập để xem lịch",
            subInfo: "",
            showProgressBar: false,
            progress: 0.0,
            countdownIos: nil,
            isExam: false,
            colorIndex: 0,
            endEstimated: false,
            deepLinkUrl: "tramkien://schedule?date=\(todayIso)"
        )
    }

    let sessions = snapshot.sessions

    func isSameDay(_ epochMs: Int64, targetDate: Date) -> Bool {
        let d = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        return calendar.isDate(d, inSameDayAs: targetDate)
    }

    let todaySessions = sessions.filter { isSameDay($0.startMs, targetDate: date) }
    let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
    let tomorrowSessions = sessions.filter { isSameDay($0.startMs, targetDate: tomorrowDate) }

    // 1. Môn đang diễn ra (current)
    let activeSessions = todaySessions.filter { $0.startMs <= nowMs && nowMs < $0.endMs }
    var selectedSession: SnapshotSessionPayload? = nil
    var statusLabel = ""

    if !activeSessions.isEmpty {
        let sorted = activeSessions.sorted { a, b in
            if a.kind == "exam" && b.kind != "exam" { return true }
            if b.kind == "exam" && a.kind != "exam" { return false }
            return a.startMs < b.startMs
        }
        let active = sorted.first!
        selectedSession = active
        statusLabel = (active.kind == "exam") ? "Đang thi" : "Đang học"
    }

    // 2. Lịch thi sắp tới trong ngày (kind == "exam" và upcoming)
    if selectedSession == nil {
        let upcomingExams = todaySessions.filter { $0.kind == "exam" && $0.startMs > nowMs }
            .sorted { $0.startMs < $1.startMs }
        if let exam = upcomingExams.first {
            selectedSession = exam
            statusLabel = "Tiếp theo"
        }
    }

    // 3. Môn sắp tới gần nhất trong ngày (kind == "class" và upcoming)
    if selectedSession == nil {
        let upcomingClasses = todaySessions.filter { $0.kind == "class" && $0.startMs > nowMs }
            .sorted { $0.startMs < $1.startMs }
        if let nextClass = upcomingClasses.first {
            selectedSession = nextClass
            statusLabel = "Tiếp theo"
        }
    }

    // 4. Hết ngày: Môn đầu tiên của ngày mai
    if selectedSession == nil && !tomorrowSessions.isEmpty {
        let sortedTomorrow = tomorrowSessions.sorted { $0.startMs < $1.startMs }
        selectedSession = sortedTomorrow.first
        statusLabel = "Ngày mai"
    }

    if let s = selectedSession {
        let isExam = s.kind == "exam"
        let isEndEstimated = s.endEstimated == true
        let isCurrent = (s.startMs <= nowMs && nowMs < s.endMs)

        let showProgress = isCurrent && !isEndEstimated
        let total = Double(s.endMs - s.startMs)
        let elapsed = Double(nowMs - s.startMs)
        let progress = total > 0 ? (elapsed / total) : 0.0

        let remainingMinutes = max(0, Int((s.endMs - nowMs) / 60000))
        let countdownIos = (isCurrent && !isEndEstimated) ? "Còn \(remainingMinutes) phút" : nil

        let startTimeDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
        let timeStr = timeFormatter.string(from: startTimeDate)
        let subInfo = s.room.trimmingCharacters(in: .whitespaces).isEmpty
            ? timeStr
            : "\(timeStr) · \(s.room.trimmingCharacters(in: .whitespaces))"

        let sessionDateIso = isoFormatter.string(from: startTimeDate)
        let deepLink = "tramkien://schedule?date=\(sessionDateIso)&sessionId=\(s.id)"

        return Today2x2ViewModel(
            stateType: "sessionActive",
            statusLabel: statusLabel,
            subjectName: s.subject,
            displayTitle: truncatePreserveSuffixSwift(s.subject, maxLength: 40),
            subInfo: subInfo,
            showProgressBar: showProgress,
            progress: progress,
            countdownIos: countdownIos,
            isExam: isExam,
            colorIndex: s.color,
            endEstimated: isEndEstimated,
            deepLinkUrl: deepLink
        )
    }

    // 5. Trạng thái trống (Mục 3.6)
    let deadlineMs = nowMs + 7 * 86400 * 1000
    let futureSessions = sessions.filter { $0.startMs > nowMs && $0.startMs <= deadlineMs }
        .sorted { $0.startMs < $1.startMs }

    let nextPreviewText: String
    if let next = futureSessions.first {
        let nextDate = Date(timeIntervalSince1970: Double(next.startMs) / 1000.0)
        let weekdayNum = calendar.component(.weekday, from: nextDate)
        let weekdayStr: String
        switch weekdayNum {
        case 2: weekdayStr = "T2"
        case 3: weekdayStr = "T3"
        case 4: weekdayStr = "T4"
        case 5: weekdayStr = "T5"
        case 6: weekdayStr = "T6"
        case 7: weekdayStr = "T7"
        default: weekdayStr = "CN"
        }
        let timeStr = timeFormatter.string(from: nextDate)
        let nameStr = (next.short?.isEmpty == false) ? next.short! : next.subject
        nextPreviewText = "Tiếp theo: \(weekdayStr) \(timeStr) \(nameStr)"
    } else {
        nextPreviewText = "Không có lịch sắp tới"
    }

    let emptyTitle = todaySessions.isEmpty
        ? "Hôm nay không có lịch"
        : "Hôm nay đã xong \(todaySessions.count) môn"

    return Today2x2ViewModel(
        stateType: todaySessions.isEmpty ? "emptyDay" : "allFinished",
        statusLabel: "",
        subjectName: emptyTitle,
        displayTitle: emptyTitle,
        subInfo: nextPreviewText,
        showProgressBar: false,
        progress: 0.0,
        countdownIos: nil,
        isExam: false,
        colorIndex: 0,
        endEstimated: false,
        deepLinkUrl: "tramkien://schedule?date=\(todayIso)"
    )
}

func evaluateMonthToday4x2(snapshot: SnapshotPayload?, at date: Date, monthOffset: Int = 0) -> MonthToday4x2ViewModel {
    var calendar = Calendar(identifier: .gregorian)
    if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        calendar.timeZone = tz
    }

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = calendar.timeZone

    let ddMmFormatter = DateFormatter()
    ddMmFormatter.dateFormat = "dd/MM"
    ddMmFormatter.timeZone = calendar.timeZone

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.timeZone = calendar.timeZone

    let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: date) ?? date
    let targetYear = calendar.component(.year, from: targetDate)
    let targetMonth = calendar.component(.month, from: targetDate)
    let monthTitle = "Tháng \(targetMonth)/\(targetYear)"

    var startOfMonthComponents = DateComponents()
    startOfMonthComponents.year = targetYear
    startOfMonthComponents.month = targetMonth
    startOfMonthComponents.day = 1
    let startOfMonth = calendar.date(from: startOfMonthComponents) ?? targetDate

    let firstDayDow = calendar.component(.weekday, from: startOfMonth)
    let emptyLeading = (firstDayDow == 1) ? 6 : (firstDayDow - 2)
    let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30

    let nowYear = calendar.component(.year, from: date)
    let nowMonth = calendar.component(.month, from: date)
    let nowDay = calendar.component(.day, from: date)

    var cells: [MonthGridDayPayload?] = []
    for idx in 0..<42 {
        if idx < emptyLeading || idx >= emptyLeading + daysInMonth {
            cells.append(nil)
        } else {
            let d = idx - emptyLeading + 1
            let isToday = (targetYear == nowYear && targetMonth == nowMonth && d == nowDay)
            let dateIso = String(format: "%04d-%02d-%02d", targetYear, targetMonth, d)

            var hasExam = false
            var hasClasses = false
            if let snapshot = snapshot, snapshot.version == 1 {
                for s in snapshot.sessions {
                    let sDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
                    if calendar.component(.year, from: sDate) == targetYear &&
                       calendar.component(.month, from: sDate) == targetMonth &&
                       calendar.component(.day, from: sDate) == d {
                        if s.kind == "exam" {
                            hasExam = true
                        } else {
                            hasClasses = true
                        }
                    }
                }
            }

            cells.append(MonthGridDayPayload(
                dateIso: dateIso,
                day: d,
                month: targetMonth,
                year: targetYear,
                isToday: isToday,
                hasClasses: hasClasses,
                hasExam: hasExam,
                deepLink: "tramkien://schedule?date=\(dateIso)"
            ))
        }
    }

    let weekdayNum = calendar.component(.weekday, from: date)
    let weekdayStr: String
    switch weekdayNum {
    case 2: weekdayStr = "T2"
    case 3: weekdayStr = "T3"
    case 4: weekdayStr = "T4"
    case 5: weekdayStr = "T5"
    case 6: weekdayStr = "T6"
    case 7: weekdayStr = "T7"
    default: weekdayStr = "CN"
    }
    let ddMmStr = ddMmFormatter.string(from: date)
    let headerLeft = "\(weekdayStr), \(ddMmStr)"
    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    guard let snapshot = snapshot, snapshot.version == 1 else {
        return MonthToday4x2ViewModel(
            monthTitle: monthTitle,
            weekdayHeaders: ["T2", "T3", "T4", "T5", "T6", "T7", "CN"],
            cells: cells,
            headerLeft: headerLeft,
            headerRight: "0 môn",
            visibleCards: [],
            overflowLabel: nil,
            emptyTitle: "Đăng nhập để xem lịch",
            emptySubtitle: ""
        )
    }

    let todaySessions = snapshot.sessions.filter {
        calendar.isDate(Date(timeIntervalSince1970: Double($0.startMs) / 1000.0), inSameDayAs: date)
    }
    let totalCount = todaySessions.count
    let headerRight = "\(totalCount) môn"

    let remainingSessions = todaySessions.filter { $0.endMs > nowMs }.sorted { $0.startMs < $1.startMs }

    if remainingSessions.isEmpty {
        let deadlineMs = nowMs + 7 * 86400 * 1000
        let futureSessions = snapshot.sessions.filter { $0.startMs > nowMs && $0.startMs <= deadlineMs }.sorted { $0.startMs < $1.startMs }

        let nextPreview: String
        if let next = futureSessions.first {
            let nextDate = Date(timeIntervalSince1970: Double(next.startMs) / 1000.0)
            let nWkNum = calendar.component(.weekday, from: nextDate)
            let nWkStr: String
            switch nWkNum {
            case 2: nWkStr = "T2"
            case 3: nWkStr = "T3"
            case 4: nWkStr = "T4"
            case 5: nWkStr = "T5"
            case 6: nWkStr = "T6"
            case 7: nWkStr = "T7"
            default: nWkStr = "CN"
            }
            let timeStr = timeFormatter.string(from: nextDate)
            let nameStr = (next.short?.isEmpty == false) ? next.short! : next.subject
            nextPreview = "Tiếp theo: \(nWkStr) \(timeStr) \(nameStr)"
        } else {
            nextPreview = "Không có lịch sắp tới"
        }

        let emptyTitle = todaySessions.isEmpty ? "Hôm nay không có lịch" : "Hôm nay đã xong \(totalCount) môn"

        return MonthToday4x2ViewModel(
            monthTitle: monthTitle,
            weekdayHeaders: ["T2", "T3", "T4", "T5", "T6", "T7", "CN"],
            cells: cells,
            headerLeft: headerLeft,
            headerRight: headerRight,
            visibleCards: [],
            overflowLabel: nil,
            emptyTitle: emptyTitle,
            emptySubtitle: nextPreview
        )
    }

    // ƯU TIÊN LỊCH THI (AC-11)
    let exams = remainingSessions.filter { $0.kind == "exam" }
    let classes = remainingSessions.filter { $0.kind != "exam" }

    var chosen: [SnapshotSessionPayload] = []
    if exams.count >= 2 {
        chosen = Array(exams.prefix(2))
    } else if exams.count == 1 {
        chosen = [exams[0]]
        if let firstClass = classes.first {
            chosen.append(firstClass)
        }
        chosen.sort { $0.startMs < $1.startMs }
    } else {
        chosen = Array(classes.prefix(2))
    }

    let visibleCards: [MonthTodayCardItemPayload] = chosen.map { s in
        let isExam = s.kind == "exam"
        let isCurrent = s.startMs <= nowMs && nowMs < s.endMs
        let startDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
        let startStr = timeFormatter.string(from: startDate)
        let roomStr = s.room.isEmpty ? "Chưa có phòng" : s.room
        let timeRoom = isExam ? "\(startStr) · \(roomStr) · Thi" : "\(startStr) · \(roomStr)"
        let displayTitle = truncatePreserveSuffixSwift(s.subject, maxLength: 36)
        let sIso = isoFormatter.string(from: startDate)
        let deepLink = "tramkien://schedule?date=\(sIso)&sessionId=\(s.id)"

        return MonthTodayCardItemPayload(
            id: s.id,
            timeRoomLine: timeRoom,
            displayTitle: displayTitle,
            isExam: isExam,
            isCurrent: isCurrent,
            colorIndex: s.color,
            deepLink: deepLink
        )
    }

    let overflow = remainingSessions.count - chosen.count
    let overflowLabel = overflow > 0 ? "+\(overflow) môn nữa" : nil

    return MonthToday4x2ViewModel(
        monthTitle: monthTitle,
        weekdayHeaders: ["T2", "T3", "T4", "T5", "T6", "T7", "CN"],
        cells: cells,
        headerLeft: headerLeft,
        headerRight: headerRight,
        visibleCards: visibleCards,
        overflowLabel: overflowLabel,
        emptyTitle: nil,
        emptySubtitle: nil
    )
}

func simplifyRoomSwift(_ rawRoom: String) -> String {
    var room = rawRoom.trimmingCharacters(in: .whitespacesAndNewlines)
    if room.isEmpty { return "" }
    if let parenRegex = try? NSRegularExpression(pattern: "\\(.*?\\)", options: []) {
        room = parenRegex.stringByReplacingMatches(in: room, range: NSRange(location: 0, length: room.utf16.count), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let pRegex = try? NSRegularExpression(pattern: "^[Pp]\\.([A-Za-z0-9]+)", options: []) {
        room = pRegex.stringByReplacingMatches(in: room, range: NSRange(location: 0, length: room.utf16.count), withTemplate: "P$1")
    }
    return room.trimmingCharacters(in: .whitespacesAndNewlines)
}

func evaluateThreeDays4x2(snapshot: SnapshotPayload?, at date: Date) -> ThreeDays4x2ViewModel {
    guard let snapshot = snapshot, snapshot.version == 1 else {
        return ThreeDays4x2ViewModel.placeholder()
    }

    var vnCalendar = Calendar(identifier: .gregorian)
    if let vnTz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        vnCalendar.timeZone = vnTz
    }

    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    if let vnTz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        timeFormatter.timeZone = vnTz
    }

    let weekdayNames = ["", "CN", "T2", "T3", "T4", "T5", "T6", "T7"]

    var columns: [ThreeDaysColumnPayload] = []

    for colIdx in 0..<3 {
        guard let colDate = vnCalendar.date(byAdding: .day, value: colIdx, to: date) else { continue }
        let year = vnCalendar.component(.year, from: colDate)
        let month = vnCalendar.component(.month, from: colDate)
        let day = vnCalendar.component(.day, from: colDate)
        let weekdayInt = vnCalendar.component(.weekday, from: colDate)

        let isToday = (colIdx == 0)
        let dayStr = String(format: "%02d", day)
        let title: String
        if isToday {
            title = "Hôm nay \(dayStr)"
        } else {
            let wkStr = (weekdayInt >= 1 && weekdayInt <= 7) ? weekdayNames[weekdayInt] : "T2"
            title = "\(wkStr) · \(dayStr)"
        }

        let dateIso = String(format: "%04d-%02d-%02d", year, month, day)

        let daySessions = snapshot.sessions.filter { s in
            let sDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
            let sYear = vnCalendar.component(.year, from: sDate)
            let sMonth = vnCalendar.component(.month, from: sDate)
            let sDay = vnCalendar.component(.day, from: sDate)
            return sYear == year && sMonth == month && sDay == day
        }.sorted { $0.startMs < $1.startMs }

        let remainingSessions: [SnapshotSessionPayload]
        if isToday {
            remainingSessions = daySessions.filter { $0.endMs > nowMs }
        } else {
            remainingSessions = daySessions
        }

        let exams = remainingSessions.filter { $0.kind == "exam" }
        let classes = remainingSessions.filter { $0.kind != "exam" }

        var chosen: [SnapshotSessionPayload] = []
        if exams.count >= 2 {
            chosen = Array(exams.prefix(2))
        } else if exams.count == 1 {
            chosen = [exams[0]] + Array(classes.prefix(1))
            chosen.sort { $0.startMs < $1.startMs }
        } else {
            chosen = Array(classes.prefix(2))
        }

        let hiddenCount = remainingSessions.count - chosen.count
        let badgeText = hiddenCount > 0 ? "+\(hiddenCount)" : nil

        let visibleCards = chosen.map { s -> ThreeDaysCardItemPayload in
            let isExam = s.kind == "exam"
            let isCurrent = isToday && (s.startMs <= nowMs && nowMs < s.endMs)
            let sStartDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
            let timeStr = timeFormatter.string(from: sStartDate)
            let roomStr = simplifyRoomSwift(s.room)
            let timeRoomLine = roomStr.isEmpty ? timeStr : "\(timeStr) · \(roomStr)"
            let rawShort = (s.short ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rawName = rawShort.isEmpty ? s.subject : rawShort
            let shortName = truncatePreserveSuffixSwift(rawName, maxLength: 24)

            let deepLink = "tramkien://schedule?date=\(dateIso)&sessionId=\(s.id)"

            return ThreeDaysCardItemPayload(
                id: s.id,
                timeStr: timeStr,
                roomStr: roomStr,
                timeRoomLine: timeRoomLine,
                shortName: shortName,
                isExam: isExam,
                isCurrent: isCurrent,
                colorIndex: s.color,
                deepLink: deepLink
            )
        }

        columns.append(ThreeDaysColumnPayload(
            dateIso: dateIso,
            title: title,
            isToday: isToday,
            visibleCards: visibleCards,
            hiddenCount: max(0, hiddenCount),
            badgeText: badgeText,
            isEmpty: visibleCards.isEmpty,
            emptyText: "Trống",
            deepLink: "tramkien://schedule?date=\(dateIso)"
        ))
    }

    return ThreeDays4x2ViewModel(
        hasSnapshot: true,
        authMessage: nil,
        columns: columns
    )
}

// MARK: - Weekly (4x4) Models (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Bước 5)

struct WeeklyDayStripPayload {
    let weekday: String
    let countText: String
    let count: Int
    let isToday: Bool
}

struct WeeklySessionRowPayload: Identifiable {
    let id: Int
    let timeStr: String
    let displayTitle: String
    let roomStr: String
    let isExam: Bool
    let isPast: Bool
    let isToday: Bool
    let colorIndex: Int
    let deepLink: String
}

struct WeeklyDayGroupPayload: Identifiable {
    let id: String
    let headerTitle: String
    let isToday: Bool
    let sessions: [WeeklySessionRowPayload]
}

struct WeeklyMergedEmptyPayload: Identifiable {
    let id: String
    let displayTitle: String
}

enum WeeklyScheduleListItemPayload: Identifiable {
    case header(WeeklyDayGroupPayload)
    case session(WeeklySessionRowPayload)
    case emptyDays(WeeklyMergedEmptyPayload)

    var id: String {
        switch self {
        case .header(let g): return "header_\(g.id)"
        case .session(let s): return "session_\(s.id)"
        case .emptyDays(let e): return "empty_\(e.id)"
        }
    }
}

struct Weekly4x4ViewModel {
    let hasSnapshot: Bool
    let authMessage: String?
    let title: String
    let daysStrip: [WeeklyDayStripPayload]
    let items: [WeeklyScheduleListItemPayload]
    let footerText: String?
    let totalSessions: Int

    static func placeholder() -> Weekly4x4ViewModel {
        let weekdayLabels = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
        let strip = weekdayLabels.map {
            WeeklyDayStripPayload(weekday: $0, countText: "\u{00B7}", count: 0, isToday: false)
        }
        return Weekly4x4ViewModel(
            hasSnapshot: false,
            authMessage: "Đăng nhập để xem lịch",
            title: "Tuần",
            daysStrip: strip,
            items: [],
            footerText: nil,
            totalSessions: 0
        )
    }
}

func evaluateWeekly4x4(snapshot: SnapshotPayload?, at date: Date, weekOffset: Int = 0) -> Weekly4x4ViewModel {
    var vnCalendar = Calendar(identifier: .gregorian)
    if let vnTz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        vnCalendar.timeZone = vnTz
    }

    let weekdayLabels = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    let dayMonthFormatter = DateFormatter()
    dayMonthFormatter.dateFormat = "dd/MM"
    if let vnTz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        dayMonthFormatter.timeZone = vnTz
    }

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    if let vnTz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        timeFormatter.timeZone = vnTz
    }

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    if let vnTz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        isoFormatter.timeZone = vnTz
    }

    let todayComponents = vnCalendar.dateComponents([.year, .month, .day, .weekday], from: date)
    let currentWeekday = todayComponents.weekday ?? 2
    let daysFromMonday = (currentWeekday == 1) ? 6 : (currentWeekday - 2)

    guard let todayStart = vnCalendar.date(from: DateComponents(year: todayComponents.year, month: todayComponents.month, day: todayComponents.day)),
          let currentMonday = vnCalendar.date(byAdding: .day, value: -daysFromMonday, to: todayStart),
          let targetMonday = vnCalendar.date(byAdding: .day, value: weekOffset * 7, to: currentMonday),
          let targetSunday = vnCalendar.date(byAdding: .day, value: 6, to: targetMonday) else {
        return Weekly4x4ViewModel.placeholder()
    }

    let weekTitle = "Tuần \(dayMonthFormatter.string(from: targetMonday)) \u{2013} \(dayMonthFormatter.string(from: targetSunday))"

    guard let snapshot = snapshot, snapshot.version == 1 else {
        let strip = (0..<7).map { i -> WeeklyDayStripPayload in
            let d = vnCalendar.date(byAdding: .day, value: i, to: targetMonday) ?? targetMonday
            let comp = vnCalendar.dateComponents([.year, .month, .day], from: d)
            let isToday = (comp.year == todayComponents.year && comp.month == todayComponents.month && comp.day == todayComponents.day)
            return WeeklyDayStripPayload(
                weekday: weekdayLabels[i],
                countText: "\u{00B7}",
                count: 0,
                isToday: isToday
            )
        }
        return Weekly4x4ViewModel(
            hasSnapshot: false,
            authMessage: "Đăng nhập để xem lịch",
            title: weekTitle,
            daysStrip: strip,
            items: [],
            footerText: nil,
            totalSessions: 0
        )
    }

    var sessionsByDay: [[SnapshotSessionPayload]] = Array(repeating: [], count: 7)
    for s in snapshot.sessions {
        let sDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
        let sComp = vnCalendar.dateComponents([.year, .month, .day], from: sDate)

        for i in 0..<7 {
            if let d = vnCalendar.date(byAdding: .day, value: i, to: targetMonday) {
                let dComp = vnCalendar.dateComponents([.year, .month, .day], from: d)
                if sComp.year == dComp.year && sComp.month == dComp.month && sComp.day == dComp.day {
                    sessionsByDay[i].append(s)
                    break
                }
            }
        }
    }

    for i in 0..<7 {
        sessionsByDay[i].sort { $0.startMs < $1.startMs }
    }

    var totalSessions = 0
    var strip: [WeeklyDayStripPayload] = []

    for i in 0..<7 {
        let count = sessionsByDay[i].count
        totalSessions += count
        let d = vnCalendar.date(byAdding: .day, value: i, to: targetMonday) ?? targetMonday
        let comp = vnCalendar.dateComponents([.year, .month, .day], from: d)
        let isToday = (comp.year == todayComponents.year && comp.month == todayComponents.month && comp.day == todayComponents.day)

        strip.append(WeeklyDayStripPayload(
            weekday: weekdayLabels[i],
            countText: count > 0 ? "\(count)" : "\u{00B7}",
            count: count,
            isToday: isToday
        ))
    }

    // Xử lý tràn chỗ & AC-11
    let maxVisibleRows = 8
    var activeExams: [SnapshotSessionPayload] = []
    var otherSessions: [SnapshotSessionPayload] = []

    for dayList in sessionsByDay {
        for s in dayList {
            let isExam = (s.kind == "exam")
            let isPast = (s.endMs <= nowMs)
            if isExam && !isPast {
                activeExams.append(s)
            } else {
                otherSessions.append(s)
            }
        }
    }

    var chosenIds = Set<Int>()
    var chosenCount = 0

    if totalSessions <= maxVisibleRows {
        for s in activeExams + otherSessions {
            chosenIds.insert(s.id)
        }
        chosenCount = totalSessions
    } else {
        for s in activeExams {
            chosenIds.insert(s.id)
            chosenCount += 1
        }
        for s in otherSessions {
            if chosenCount >= maxVisibleRows { break }
            if !chosenIds.contains(s.id) {
                chosenIds.insert(s.id)
                chosenCount += 1
            }
        }
    }

    let hiddenCount = totalSessions - chosenIds.count
    let footerText = hiddenCount > 0 ? "+\(hiddenCount) môn nữa" : nil

    var items: [WeeklyScheduleListItemPayload] = []
    var emptyStart = -1

    func flushEmpty(_ currentIdx: Int) {
        if emptyStart != -1 {
            let startIdx = emptyStart
            let endIdx = currentIdx - 1
            let startWk = weekdayLabels[startIdx]
            let endWk = weekdayLabels[endIdx]
            let title = (startIdx == endIdx) ? "\(startWk): không có lịch" : "\(startWk) \u{2013} \(endWk): không có lịch"
            items.append(.emptyDays(WeeklyMergedEmptyPayload(id: "\(startIdx)_\(endIdx)", displayTitle: title)))
            emptyStart = -1
        }
    }

    for i in 0..<7 {
        let daySessions = sessionsByDay[i]
        let visibleInDay = daySessions.filter { chosenIds.contains($0.id) }

        if daySessions.isEmpty {
            if emptyStart == -1 {
                emptyStart = i
            }
        } else {
            flushEmpty(i)

            let d = vnCalendar.date(byAdding: .day, value: i, to: targetMonday) ?? targetMonday
            let comp = vnCalendar.dateComponents([.year, .month, .day], from: d)
            let isToday = (comp.year == todayComponents.year && comp.month == todayComponents.month && comp.day == todayComponents.day)
            let wkStr = weekdayLabels[i]
            let dateStr = dayMonthFormatter.string(from: d)
            let dateIso = isoFormatter.string(from: d)

            let headerTitle = isToday ? "Hôm nay \u{00B7} \(wkStr) \(dateStr)" : "\(wkStr) \(dateStr)"

            if !visibleInDay.isEmpty {
                let rowPayloads = visibleInDay.map { s -> WeeklySessionRowPayload in
                    let isExam = (s.kind == "exam")
                    let isPast = (s.endMs <= nowMs)
                    let sDate = Date(timeIntervalSince1970: Double(s.startMs) / 1000.0)
                    let timeStr = timeFormatter.string(from: sDate)
                    let roomStr = simplifyRoomSwift(s.room)
                    let rawTitle = s.subject.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayTitle = isExam ? "Thi \(rawTitle)" : rawTitle
                    let deepLink = "tramkien://schedule?date=\(dateIso)&sessionId=\(s.id)"

                    return WeeklySessionRowPayload(
                        id: s.id,
                        timeStr: timeStr,
                        displayTitle: displayTitle,
                        roomStr: roomStr,
                        isExam: isExam,
                        isPast: isPast,
                        isToday: isToday,
                        colorIndex: s.color,
                        deepLink: deepLink
                    )
                }

                let groupPayload = WeeklyDayGroupPayload(
                    id: dateIso,
                    headerTitle: headerTitle,
                    isToday: isToday,
                    sessions: rowPayloads
                )

                items.append(.header(groupPayload))
                for row in rowPayloads {
                    items.append(.session(row))
                }
            }
        }
    }

    flushEmpty(7)

    return Weekly4x4ViewModel(
        hasSnapshot: true,
        authMessage: nil,
        title: weekTitle,
        daysStrip: strip,
        items: items,
        footerText: footerText,
        totalSessions: totalSessions
    )
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Bước 6: Lock Screen Models

struct LockScreenRectangularViewModel {
    let line1: String
    let line2: String
    let line3: String?
    let isExam: Bool
    let endEstimated: Bool
    let deepLinkUrl: String

    static func placeholder() -> LockScreenRectangularViewModel {
        LockScreenRectangularViewModel(
            line1: "Đăng nhập để xem lịch",
            line2: "",
            line3: nil,
            isExam: false,
            endEstimated: false,
            deepLinkUrl: "tramkien://schedule"
        )
    }
}

struct LockScreenCircularViewModel {
    let centerText: String
    let progress: Double
    let hasActiveSession: Bool
    let deepLinkUrl: String

    static func placeholder() -> LockScreenCircularViewModel {
        LockScreenCircularViewModel(
            centerText: "--:--",
            progress: 0.0,
            hasActiveSession: false,
            deepLinkUrl: "tramkien://schedule"
        )
    }
}

struct LockScreenInlineViewModel {
    let text: String
    let deepLinkUrl: String

    static func placeholder() -> LockScreenInlineViewModel {
        LockScreenInlineViewModel(
            text: "Đăng nhập để xem lịch",
            deepLinkUrl: "tramkien://schedule"
        )
    }
}

func evaluateLockScreenRectangular(snapshot: SnapshotPayload?, at date: Date) -> LockScreenRectangularViewModel {
    var calendar = Calendar(identifier: .gregorian)
    if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        calendar.timeZone = tz
    }

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = calendar.timeZone

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.timeZone = calendar.timeZone

    let todayIso = isoFormatter.string(from: date)
    let fallbackDeepLink = "tramkien://schedule?date=\(todayIso)"
    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    guard let snapshot = snapshot, snapshot.version == 1 else {
        return LockScreenRectangularViewModel.placeholder()
    }

    func isSameDay(_ epochMs: Int64, targetDate: Date) -> Bool {
        let d = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        return calendar.isDate(d, inSameDayAs: targetDate)
    }

    let sessions = snapshot.sessions
    let todaySessions = sessions.filter { isSameDay($0.startMs, targetDate: date) }

    // 1. Môn đang diễn ra (current)
    let activeSessions = todaySessions.filter { $0.startMs <= nowMs && nowMs < $0.endMs }
    if !activeSessions.isEmpty {
        let sorted = activeSessions.sorted { a, b in
            if a.kind == "exam" && b.kind != "exam" { return true }
            if b.kind == "exam" && a.kind != "exam" { return false }
            return a.startMs < b.startMs
        }
        let active = sorted.first!
        let isExam = active.kind == "exam"
        let isEndEstimated = active.endEstimated == true
        let timeStr = timeFormatter.string(from: Date(timeIntervalSince1970: Double(active.startMs) / 1000.0))
        let line1 = isExam ? "Đang thi · \(timeStr)" : "Đang học · \(timeStr)"
        let title = (active.short?.isEmpty == false) ? active.short! : truncatePreserveSuffixSwift(active.subject, maxLength: 24)
        let line2 = title

        var line3: String? = nil
        if isExam && isEndEstimated {
            line3 = nil
        } else {
            let remaining = max(0, Int((active.endMs - nowMs) / 60000))
            let room = simplifyRoomSwift(active.room)
            line3 = room.isEmpty ? "còn \(remaining) phút" : "\(room) · còn \(remaining) phút"
        }

        let sessionDateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(active.startMs) / 1000.0))
        return LockScreenRectangularViewModel(
            line1: line1,
            line2: line2,
            line3: line3,
            isExam: isExam,
            endEstimated: isEndEstimated,
            deepLinkUrl: "tramkien://schedule?date=\(sessionDateIso)&sessionId=\(active.id)"
        )
    }

    // 2. Môn sắp tới trong ngày (upcoming)
    let upcomingExams = todaySessions.filter { $0.kind == "exam" && $0.startMs > nowMs }
        .sorted { $0.startMs < $1.startMs }
    let upcomingClasses = todaySessions.filter { $0.kind == "class" && $0.startMs > nowMs }
        .sorted { $0.startMs < $1.startMs }

    let nextSession: SnapshotSessionPayload? = upcomingExams.first ?? upcomingClasses.first

    if let next = nextSession {
        let isExam = next.kind == "exam"
        let timeStr = timeFormatter.string(from: Date(timeIntervalSince1970: Double(next.startMs) / 1000.0))
        let line1 = "Tiếp theo · \(timeStr)"
        let title = (next.short?.isEmpty == false) ? next.short! : truncatePreserveSuffixSwift(next.subject, maxLength: 24)
        let minutesUntil = max(0, Int((next.startMs - nowMs) / 60000))
        let room = simplifyRoomSwift(next.room)
        let line3 = room.isEmpty ? "còn \(minutesUntil) phút" : "\(room) · còn \(minutesUntil) phút"

        let sessionDateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(next.startMs) / 1000.0))
        return LockScreenRectangularViewModel(
            line1: line1,
            line2: title,
            line3: line3,
            isExam: isExam,
            endEstimated: next.endEstimated == true,
            deepLinkUrl: "tramkien://schedule?date=\(sessionDateIso)&sessionId=\(next.id)"
        )
    }

    // 3. Trạng thái trống
    let deadlineMs = nowMs + 7 * 86400 * 1000
    let futureSessions = sessions.filter { $0.startMs > nowMs && $0.startMs <= deadlineMs }
        .sorted { $0.startMs < $1.startMs }

    let nextPreviewText: String
    if let next = futureSessions.first {
        let nextDate = Date(timeIntervalSince1970: Double(next.startMs) / 1000.0)
        let weekdayNum = calendar.component(.weekday, from: nextDate)
        let weekdayStr: String
        switch weekdayNum {
        case 2: weekdayStr = "T2"
        case 3: weekdayStr = "T3"
        case 4: weekdayStr = "T4"
        case 5: weekdayStr = "T5"
        case 6: weekdayStr = "T6"
        case 7: weekdayStr = "T7"
        default: weekdayStr = "CN"
        }
        let timeStr = timeFormatter.string(from: nextDate)
        let nameStr = (next.short?.isEmpty == false) ? next.short! : next.subject
        nextPreviewText = "Tiếp theo: \(weekdayStr) \(timeStr) \(nameStr)"
    } else {
        nextPreviewText = "Không có lịch sắp tới"
    }

    let line1 = todaySessions.isEmpty ? "Hôm nay không có lịch" : "Hôm nay đã xong \(todaySessions.count) môn"
    return LockScreenRectangularViewModel(
        line1: line1,
        line2: nextPreviewText,
        line3: nil,
        isExam: false,
        endEstimated: false,
        deepLinkUrl: fallbackDeepLink
    )
}

func evaluateLockScreenCircular(snapshot: SnapshotPayload?, at date: Date) -> LockScreenCircularViewModel {
    var calendar = Calendar(identifier: .gregorian)
    if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        calendar.timeZone = tz
    }

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = calendar.timeZone

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.timeZone = calendar.timeZone

    let todayIso = isoFormatter.string(from: date)
    let fallbackDeepLink = "tramkien://schedule?date=\(todayIso)"
    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    guard let snapshot = snapshot, snapshot.version == 1 else {
        return LockScreenCircularViewModel.placeholder()
    }

    func isSameDay(_ epochMs: Int64, targetDate: Date) -> Bool {
        let d = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        return calendar.isDate(d, inSameDayAs: targetDate)
    }

    let sessions = snapshot.sessions
    let todaySessions = sessions.filter { isSameDay($0.startMs, targetDate: date) }

    // Môn đang diễn ra (current)
    let activeSessions = todaySessions.filter { $0.startMs <= nowMs && nowMs < $0.endMs }
    var progress: Double = 0.0
    var activeSession: SnapshotSessionPayload? = nil

    if !activeSessions.isEmpty {
        let sorted = activeSessions.sorted { a, b in
            if a.kind == "exam" && b.kind != "exam" { return true }
            if b.kind == "exam" && a.kind != "exam" { return false }
            return a.startMs < b.startMs
        }
        let active = sorted.first!
        activeSession = active

        if active.kind == "exam" && active.endEstimated == true {
            progress = 0.0
        } else {
            let total = Double(active.endMs - active.startMs)
            let elapsed = Double(nowMs - active.startMs)
            progress = total > 0 ? min(1.0, max(0.0, elapsed / total)) : 0.0
        }
    }

    // Giờ giữa: môn kế tiếp trong ngày, hoặc môn ngày mai, hoặc "--:--"
    let upcomingToday = todaySessions.filter { $0.startMs > nowMs }.sorted { $0.startMs < $1.startMs }
    let centerText: String

    if let next = upcomingToday.first {
        centerText = timeFormatter.string(from: Date(timeIntervalSince1970: Double(next.startMs) / 1000.0))
    } else {
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        let tomorrowSessions = sessions.filter { isSameDay($0.startMs, targetDate: tomorrowDate) }
            .sorted { $0.startMs < $1.startMs }
        if let firstTomorrow = tomorrowSessions.first {
            centerText = timeFormatter.string(from: Date(timeIntervalSince1970: Double(firstTomorrow.startMs) / 1000.0))
        } else {
            centerText = "--:--"
        }
    }

    let deepLink: String
    if let a = activeSession {
        let sDateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(a.startMs) / 1000.0))
        deepLink = "tramkien://schedule?date=\(sDateIso)&sessionId=\(a.id)"
    } else {
        deepLink = fallbackDeepLink
    }

    return LockScreenCircularViewModel(
        centerText: centerText,
        progress: progress,
        hasActiveSession: activeSession != nil,
        deepLinkUrl: deepLink
    )
}

func evaluateLockScreenInline(snapshot: SnapshotPayload?, at date: Date) -> LockScreenInlineViewModel {
    var calendar = Calendar(identifier: .gregorian)
    if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
        calendar.timeZone = tz
    }

    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = calendar.timeZone

    let isoFormatter = DateFormatter()
    isoFormatter.dateFormat = "yyyy-MM-dd"
    isoFormatter.timeZone = calendar.timeZone

    let todayIso = isoFormatter.string(from: date)
    let fallbackDeepLink = "tramkien://schedule?date=\(todayIso)"
    let nowMs = Int64(date.timeIntervalSince1970 * 1000)

    guard let snapshot = snapshot, snapshot.version == 1 else {
        return LockScreenInlineViewModel.placeholder()
    }

    func isSameDay(_ epochMs: Int64, targetDate: Date) -> Bool {
        let d = Date(timeIntervalSince1970: Double(epochMs) / 1000.0)
        return calendar.isDate(d, inSameDayAs: targetDate)
    }

    let sessions = snapshot.sessions
    let todaySessions = sessions.filter { isSameDay($0.startMs, targetDate: date) }

    // 1. Môn đang diễn ra (current)
    let activeSessions = todaySessions.filter { $0.startMs <= nowMs && nowMs < $0.endMs }
    if !activeSessions.isEmpty {
        let sorted = activeSessions.sorted { a, b in
            if a.kind == "exam" && b.kind != "exam" { return true }
            if b.kind == "exam" && a.kind != "exam" { return false }
            return a.startMs < b.startMs
        }
        let active = sorted.first!
        let timeStr = timeFormatter.string(from: Date(timeIntervalSince1970: Double(active.startMs) / 1000.0))
        let short = (active.short?.isEmpty == false) ? active.short! : active.subject
        let room = simplifyRoomSwift(active.room)
        let text = room.isEmpty ? "\(timeStr) \(short)" : "\(timeStr) \(short) · \(room)"
        let sDateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(active.startMs) / 1000.0))
        return LockScreenInlineViewModel(
            text: text,
            deepLinkUrl: "tramkien://schedule?date=\(sDateIso)&sessionId=\(active.id)"
        )
    }

    // 2. Môn sắp tới trong ngày
    let upcomingToday = todaySessions.filter { $0.startMs > nowMs }.sorted { $0.startMs < $1.startMs }
    if let next = upcomingToday.first {
        let timeStr = timeFormatter.string(from: Date(timeIntervalSince1970: Double(next.startMs) / 1000.0))
        let short = (next.short?.isEmpty == false) ? next.short! : next.subject
        let room = simplifyRoomSwift(next.room)
        let text = room.isEmpty ? "\(timeStr) \(short)" : "\(timeStr) \(short) · \(room)"
        let sDateIso = isoFormatter.string(from: Date(timeIntervalSince1970: Double(next.startMs) / 1000.0))
        return LockScreenInlineViewModel(
            text: text,
            deepLinkUrl: "tramkien://schedule?date=\(sDateIso)&sessionId=\(next.id)"
        )
    }

    // 3. Không có lịch hôm nay
    return LockScreenInlineViewModel(
        text: "Không có lịch hôm nay",
        deepLinkUrl: fallbackDeepLink
    )
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
    let today2x2: Today2x2ViewModel
    let monthToday4x2: MonthToday4x2ViewModel
    let threeDays4x2: ThreeDays4x2ViewModel
    let weekly4x4: Weekly4x4ViewModel
    let lockScreenRectangular: LockScreenRectangularViewModel
    let lockScreenCircular: LockScreenCircularViewModel
    let lockScreenInline: LockScreenInlineViewModel
    let layoutMode: String
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
        let isTimelineDynamic = context.family == .systemSmall ||
            context.family == .systemMedium ||
            context.family == .systemLarge ||
            context.family == .accessoryRectangular ||
            context.family == .accessoryCircular ||
            context.family == .accessoryInline
        if isTimelineDynamic {
            let snapshot = readSnapshotFromAppGroup()
            let now = Date()
            let nowMs = Int64(now.timeIntervalSince1970 * 1000)
            var calendar = Calendar(identifier: .gregorian)
            if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
                calendar.timeZone = tz
            }

            guard let snapshot = snapshot, snapshot.version == 1 else {
                let entry = ScheduleTimelineProvider.loadData(for: context.family)
                let nextUpdate = calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
                completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
                return
            }

            let todaySessions = snapshot.sessions.filter {
                calendar.isDate(Date(timeIntervalSince1970: Double($0.startMs) / 1000.0), inSameDayAs: now)
            }

            var candidateDates: [Date] = [now]
            for s in todaySessions {
                if s.startMs > nowMs {
                    candidateDates.append(Date(timeIntervalSince1970: Double(s.startMs) / 1000.0))
                }
                if s.endMs > nowMs {
                    candidateDates.append(Date(timeIntervalSince1970: Double(s.endMs) / 1000.0))
                }
            }

            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(86400)
            let startOfTomorrow = calendar.startOfDay(for: tomorrow)
            candidateDates.append(startOfTomorrow)

            let sortedDates = Array(Set(candidateDates)).sorted()
            var entries: [ScheduleWidgetEntry] = []

            for d in sortedDates {
                let t2x2 = evaluateToday2x2(snapshot: snapshot, at: d)
                let m4x2 = evaluateMonthToday4x2(snapshot: snapshot, at: d)
                let t3d = evaluateThreeDays4x2(snapshot: snapshot, at: d)
                let w4x4 = evaluateWeekly4x4(snapshot: snapshot, at: d)
                let lRect = evaluateLockScreenRectangular(snapshot: snapshot, at: d)
                let lCirc = evaluateLockScreenCircular(snapshot: snapshot, at: d)
                let lInln = evaluateLockScreenInline(snapshot: snapshot, at: d)
                let entry = ScheduleWidgetEntry(
                    date: d,
                    title: "LỊCH HÔM NAY",
                    subtitle: "",
                    dayLabel: "HÔM NAY",
                    weekdayStr: "",
                    dateStr: "",
                    courseName: t2x2.subjectName,
                    classCode: "",
                    timeSlot: "",
                    room: "",
                    showTeacher: false,
                    showClassCode: false,
                    isGlass: false,
                    bgColorHex: "#FFFFFF",
                    bgOpacity: 1.0,
                    accentColorHex: "#185FA5",
                    primaryColorHex: "#1F1F1E",
                    secondaryColorHex: "#5F5E5A",
                    days: [],
                    todayClasses: [],
                    isLoggedIn: true,
                    today2x2: t2x2,
                    monthToday4x2: m4x2,
                    threeDays4x2: t3d,
                    weekly4x4: w4x4,
                    lockScreenRectangular: lRect,
                    lockScreenCircular: lCirc,
                    lockScreenInline: lInln,
                    layoutMode: "three_days"
                )
                entries.append(entry)
            }

            completion(Timeline(entries: entries, policy: .after(startOfTomorrow)))
            return
        }

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

        let today2x2Model = evaluateToday2x2(snapshot: readSnapshotFromAppGroup(), at: Date())
        let monthToday4x2Model = evaluateMonthToday4x2(snapshot: readSnapshotFromAppGroup(), at: Date())
        let threeDays4x2Model = evaluateThreeDays4x2(snapshot: readSnapshotFromAppGroup(), at: Date())
        let weekly4x4Model = evaluateWeekly4x4(snapshot: readSnapshotFromAppGroup(), at: Date())
        let lockScreenRectModel = evaluateLockScreenRectangular(snapshot: readSnapshotFromAppGroup(), at: Date())
        let lockScreenCircModel = evaluateLockScreenCircular(snapshot: readSnapshotFromAppGroup(), at: Date())
        let lockScreenInlnModel = evaluateLockScreenInline(snapshot: readSnapshotFromAppGroup(), at: Date())
        let effectiveLayout = themeConfig?.layoutMode ?? scheduleData?.layoutMode ?? "three_days"

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
            isLoggedIn: isLoggedIn,
            today2x2: today2x2Model,
            monthToday4x2: monthToday4x2Model,
            threeDays4x2: threeDays4x2Model,
            weekly4x4: weekly4x4Model,
            lockScreenRectangular: lockScreenRectModel,
            lockScreenCircular: lockScreenCircModel,
            lockScreenInline: lockScreenInlnModel,
            layoutMode: effectiveLayout
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
            timeSlot: "",
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
            isLoggedIn: true,
            today2x2: Today2x2ViewModel.placeholder(),
            monthToday4x2: MonthToday4x2ViewModel.placeholder(),
            threeDays4x2: ThreeDays4x2ViewModel.placeholder(),
            weekly4x4: Weekly4x4ViewModel.placeholder(),
            lockScreenRectangular: LockScreenRectangularViewModel.placeholder(),
            lockScreenCircular: LockScreenCircularViewModel.placeholder(),
            lockScreenInline: LockScreenInlineViewModel.placeholder(),
            layoutMode: "three_days"
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

struct Today2x2SwiftUIView: View {
    @Environment(\.colorScheme) var colorScheme
    let viewModel: Today2x2ViewModel

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? (Color(hex: "#262624") ?? Color.black) : Color.white
        let borderColor = isDark ? (Color(hex: "#3D3D3A") ?? Color.gray) : (Color(hex: "#E5E5E5") ?? Color.gray)
        let textPrimary = isDark ? (Color(hex: "#F1EFE8") ?? Color.white) : (Color(hex: "#1F1F1E") ?? Color.black)
        let textSecondary = isDark ? (Color(hex: "#B4B2A9") ?? Color.gray) : (Color(hex: "#5F5E5A") ?? Color.gray)
        let accentColor = isDark ? (Color(hex: "#85B7EB") ?? Color.blue) : (Color(hex: "#185FA5") ?? Color.blue)
        let examTextColor = isDark ? (Color(hex: "#F7C1C1") ?? Color.red) : (Color(hex: "#791F1F") ?? Color.red)

        let labelColor: Color = {
            if viewModel.statusLabel == "Đang thi" {
                return examTextColor
            } else if viewModel.statusLabel == "Đang học" {
                return accentColor
            }
            return textSecondary
        }()

        VStack(alignment: .leading, spacing: 0) {
            // 1. Nhãn trạng thái (cỡ 11, font vừa 500)
            if !viewModel.statusLabel.isEmpty {
                Text(viewModel.statusLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
                Spacer().frame(height: 6)
            }

            // 2. Tên môn / Trạng thái trống (cỡ 13, font vừa 500, tối đa 3 dòng)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.displayTitle)
                    .font(.system(size: viewModel.hasSession ? 13 : 12, weight: .medium))
                    .foregroundColor(textPrimary)
                    .lineLimit(viewModel.hasSession ? 3 : 2)
                    .lineSpacing(2)

                // 3. Dòng thông tin phụ: "HH:mm · phòng" (cỡ 11, màu chữ phụ)
                if !viewModel.subInfo.isEmpty {
                    Text(viewModel.subInfo)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // 4. Thanh tiến độ ca học (cao 4dp, bo góc 2dp, sát đáy)
            if viewModel.showProgressBar {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(borderColor)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(viewModel.isExam ? examTextColor : accentColor)
                            .frame(width: geo.size.width * CGFloat(min(max(viewModel.progress, 0.0), 1.0)), height: 4)
                    }
                }
                .frame(height: 4)
                Spacer().frame(height: 4)
            }

            // 5. Dòng đếm ngược đáy: Cỡ 11, màu phụ ("Còn N phút")
            if let countdown = viewModel.countdownIos, !countdown.isEmpty {
                Text(countdown)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bgColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 0.5)
        )
        .widgetURL(URL(string: viewModel.deepLinkUrl))
    }
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: Bước 3 - Month + Today 4x2 View

struct MonthToday4x2SwiftUIView: View {
    @Environment(\.colorScheme) var colorScheme
    let viewModel: MonthToday4x2ViewModel

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? (Color(hex: "#262624") ?? Color.black) : Color.white
        let borderColor = isDark ? (Color(hex: "#3D3D3A") ?? Color.gray) : (Color(hex: "#E5E5E5") ?? Color.gray)
        let textPrimary = isDark ? (Color(hex: "#F1EFE8") ?? Color.white) : (Color(hex: "#1F1F1E") ?? Color.black)
        let textSecondary = isDark ? (Color(hex: "#B4B2A9") ?? Color.gray) : (Color(hex: "#5F5E5A") ?? Color.gray)
        let accentColor = isDark ? (Color(hex: "#85B7EB") ?? Color.blue) : (Color(hex: "#185FA5") ?? Color.blue)
        let accentOn = isDark ? (Color(hex: "#042C53") ?? Color.black) : Color.white
        let examColor = isDark ? (Color(hex: "#F7C1C1") ?? Color.red) : (Color(hex: "#791F1F") ?? Color.red)
        let examBg = isDark ? (Color(hex: "#791F1F") ?? Color.red) : (Color(hex: "#FCEBEB") ?? Color.red)
        let accentBorder = isDark ? (Color(hex: "#85B7EB") ?? Color.blue) : (Color(hex: "#378ADD") ?? Color.blue)

        let lightColors: [(bg: Color, text: Color)] = [
            (Color(hex: "#E6F1FB") ?? .blue, Color(hex: "#0C447C") ?? .blue),
            (Color(hex: "#EAF3DE") ?? .green, Color(hex: "#27500A") ?? .green),
            (Color(hex: "#EEEDFE") ?? .purple, Color(hex: "#3C3489") ?? .purple),
            (Color(hex: "#FAEEDA") ?? .orange, Color(hex: "#633806") ?? .orange),
            (Color(hex: "#E1F5EE") ?? .teal, Color(hex: "#085041") ?? .teal),
            (Color(hex: "#FBEAF0") ?? .pink, Color(hex: "#72243E") ?? .pink),
            (Color(hex: "#FAECE7") ?? .red, Color(hex: "#712B13") ?? .red),
            (Color(hex: "#F1EFE8") ?? .gray, Color(hex: "#444441") ?? .gray),
        ]
        let darkColors: [(bg: Color, text: Color)] = [
            (Color(hex: "#0C447C") ?? .blue, Color(hex: "#B5D4F4") ?? .blue),
            (Color(hex: "#27500A") ?? .green, Color(hex: "#C0DD97") ?? .green),
            (Color(hex: "#3C3489") ?? .purple, Color(hex: "#CECBF6") ?? .purple),
            (Color(hex: "#633806") ?? .orange, Color(hex: "#FAC775") ?? .orange),
            (Color(hex: "#085041") ?? .teal, Color(hex: "#9FE1CB") ?? .teal),
            (Color(hex: "#72243E") ?? .pink, Color(hex: "#F4C0D1") ?? .pink),
            (Color(hex: "#712B13") ?? .red, Color(hex: "#F5C4B3") ?? .red),
            (Color(hex: "#444441") ?? .gray, Color(hex: "#D3D1C7") ?? .gray),
        ]

        HStack(alignment: .top, spacing: 10) {
            // Nửa trái: Lưới tháng
            VStack(alignment: .center, spacing: 2) {
                // Tiêu đề tháng
                HStack {
                    Text(viewModel.monthTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary)
                }

                // Hàng thứ
                HStack(spacing: 0) {
                    ForEach(viewModel.weekdayHeaders, id: \.self) { h in
                        Text(h)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundColor(textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Lưới 6 hàng x 7 cột
                VStack(spacing: 1) {
                    ForEach(0..<6, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { c in
                                let idx = r * 7 + c
                                if idx < viewModel.cells.count, let cell = viewModel.cells[idx] {
                                    Link(destination: URL(string: cell.deepLink)!) {
                                        VStack(spacing: 1) {
                                            if cell.isToday {
                                                Text("\(cell.day)")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(accentOn)
                                                    .frame(width: 14, height: 14)
                                                    .background(Circle().fill(accentColor))
                                                if cell.hasExam {
                                                    Circle()
                                                        .fill(examColor)
                                                        .frame(width: 3, height: 3)
                                                } else {
                                                    Spacer().frame(height: 3)
                                                }
                                            } else {
                                                Text("\(cell.day)")
                                                    .font(.system(size: 10, weight: (cell.hasClasses || cell.hasExam) ? .medium : .regular))
                                                    .foregroundColor((cell.hasClasses || cell.hasExam) ? textPrimary : textSecondary)
                                                    .frame(height: 14)
                                                if cell.hasExam {
                                                    Circle()
                                                        .fill(examColor)
                                                        .frame(width: 3, height: 3)
                                                } else if cell.hasClasses {
                                                    Circle()
                                                        .fill(textSecondary)
                                                        .frame(width: 3, height: 3)
                                                } else {
                                                    Spacer().frame(height: 3)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                } else {
                                    VStack(spacing: 1) {
                                        Spacer().frame(height: 14)
                                        Spacer().frame(height: 3)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // Nửa phải: Lịch hôm nay
            VStack(alignment: .leading, spacing: 4) {
                // Header: Thứ, dd/MM và N môn
                HStack {
                    Text(viewModel.headerLeft)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary)
                    Spacer()
                    Text(viewModel.headerRight)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(textSecondary)
                }

                if let emptyTitle = viewModel.emptyTitle {
                    Spacer()
                    Text(emptyTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textPrimary)
                    if let sub = viewModel.emptySubtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                } else {
                    VStack(spacing: 4) {
                        ForEach(viewModel.visibleCards) { card in
                            let cardColorIdx = min(max(card.colorIndex, 0), 7)
                            let (tokenBg, tokenText) = isDark ? darkColors[cardColorIdx] : lightColors[cardColorIdx]
                            let finalBg = card.isExam ? examBg : tokenBg
                            let finalText = card.isExam ? examColor : tokenText

                            Link(destination: URL(string: card.deepLink)!) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(card.timeRoomLine)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(finalText)
                                        .lineLimit(1)
                                    Text(card.displayTitle)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(finalText)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(finalBg)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(card.isCurrent ? accentBorder : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                    }
                    Spacer()
                    if let overflow = viewModel.overflowLabel {
                        Text(overflow)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bgColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: Bước 4 - Three Days 4x2 View

struct ThreeDays4x2SwiftUIView: View {
    @Environment(\.colorScheme) var colorScheme
    let viewModel: ThreeDays4x2ViewModel

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? (Color(hex: "#262624") ?? Color.black) : Color.white
        let borderColor = isDark ? (Color(hex: "#3D3D3A") ?? Color.gray) : (Color(hex: "#E5E5E5") ?? Color.gray)
        let textPrimary = isDark ? (Color(hex: "#F1EFE8") ?? Color.white) : (Color(hex: "#1F1F1E") ?? Color.black)
        let textSecondary = isDark ? (Color(hex: "#B4B2A9") ?? Color.gray) : (Color(hex: "#5F5E5A") ?? Color.gray)
        let textDimmed = Color(hex: "#888780") ?? Color.gray
        let accentBorder = isDark ? (Color(hex: "#85B7EB") ?? Color.blue) : (Color(hex: "#378ADD") ?? Color.blue)
        let examBg = isDark ? (Color(hex: "#791F1F") ?? Color.red) : (Color(hex: "#FCEBEB") ?? Color.red)
        let examText = isDark ? (Color(hex: "#F7C1C1") ?? Color.red) : (Color(hex: "#791F1F") ?? Color.red)

        let lightColors: [(bg: Color, text: Color)] = [
            (Color(hex: "#E6F1FB") ?? .blue, Color(hex: "#0C447C") ?? .blue),
            (Color(hex: "#EAF3DE") ?? .green, Color(hex: "#27500A") ?? .green),
            (Color(hex: "#EEEDFE") ?? .purple, Color(hex: "#3C3489") ?? .purple),
            (Color(hex: "#FAEEDA") ?? .orange, Color(hex: "#633806") ?? .orange),
            (Color(hex: "#E1F5EE") ?? .teal, Color(hex: "#085041") ?? .teal),
            (Color(hex: "#FBEAF0") ?? .pink, Color(hex: "#72243E") ?? .pink),
            (Color(hex: "#FAECE7") ?? .red, Color(hex: "#712B13") ?? .red),
            (Color(hex: "#F1EFE8") ?? .gray, Color(hex: "#444441") ?? .gray),
        ]
        let darkColors: [(bg: Color, text: Color)] = [
            (Color(hex: "#0C447C") ?? .blue, Color(hex: "#B5D4F4") ?? .blue),
            (Color(hex: "#27500A") ?? .green, Color(hex: "#C0DD97") ?? .green),
            (Color(hex: "#3C3489") ?? .purple, Color(hex: "#CECBF6") ?? .purple),
            (Color(hex: "#633806") ?? .orange, Color(hex: "#FAC775") ?? .orange),
            (Color(hex: "#085041") ?? .teal, Color(hex: "#9FE1CB") ?? .teal),
            (Color(hex: "#72243E") ?? .pink, Color(hex: "#F4C0D1") ?? .pink),
            (Color(hex: "#712B13") ?? .red, Color(hex: "#F5C4B3") ?? .red),
            (Color(hex: "#444441") ?? .gray, Color(hex: "#D3D1C7") ?? .gray),
        ]

        Group {
            if !viewModel.hasSnapshot {
                VStack {
                    Spacer()
                    Text(viewModel.authMessage ?? "Đăng nhập để xem lịch")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    Spacer()
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(viewModel.columns) { col in
                        VStack(alignment: .leading, spacing: 6) {
                            // Tiêu đề cột: "Hôm nay dd" / "Thứ · dd", "+N"
                            HStack {
                                Text(col.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                if let badge = col.badgeText {
                                    Text(badge)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(textSecondary)
                                }
                            }

                            // Thân cột: Trống hoặc tối đa 2 thẻ môn
                            if col.isEmpty {
                                VStack {
                                    Text(col.emptyText)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(textDimmed)
                                        .padding(.top, 8)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            } else {
                                VStack(spacing: 4) {
                                    ForEach(col.visibleCards) { card in
                                        let cardBg: Color = card.isExam ? examBg : (isDark ? darkColors[card.colorIndex % 8].bg : lightColors[card.colorIndex % 8].bg)
                                        let textColor: Color = card.isExam ? examText : (isDark ? darkColors[card.colorIndex % 8].text : lightColors[card.colorIndex % 8].text)

                                        Link(destination: URL(string: card.deepLink) ?? URL(string: "tramkien://schedule")!) {
                                            VStack(alignment: .leading, spacing: 1) {
                                                // Dòng 1: "HH:mm · phòng" (vừa)
                                                Text(card.timeRoomLine)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(textColor)
                                                    .lineLimit(1)

                                                // Dòng 2: shortName 1 dòng
                                                Text(card.shortName)
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(textColor)
                                                    .lineLimit(1)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(cardBg)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(card.isCurrent ? accentBorder : Color.clear, lineWidth: card.isCurrent ? 1.0 : 0.0)
                                            )
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bgColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: Bước 5 - Weekly 4x4 View

struct Weekly4x4SwiftUIView: View {
    @Environment(\.colorScheme) var colorScheme
    let viewModel: Weekly4x4ViewModel

    var body: some View {
        let isDark = colorScheme == .dark
        let bgColor = isDark ? (Color(hex: "#262624") ?? Color.black) : Color.white
        let borderColor = isDark ? (Color(hex: "#3D3D3A") ?? Color.gray) : (Color(hex: "#E5E5E5") ?? Color.gray)
        let textPrimary = isDark ? (Color(hex: "#F1EFE8") ?? Color.white) : (Color(hex: "#1F1F1E") ?? Color.black)
        let textSecondary = isDark ? (Color(hex: "#B4B2A9") ?? Color.gray) : (Color(hex: "#5F5E5A") ?? Color.gray)
        let textDimmed = Color(hex: "#888780") ?? Color.gray
        let accentColor = isDark ? (Color(hex: "#85B7EB") ?? Color.blue) : (Color(hex: "#185FA5") ?? Color.blue)
        let accentOn = isDark ? (Color(hex: "#042C53") ?? Color.black) : Color.white
        let examColor = isDark ? (Color(hex: "#F7C1C1") ?? Color.red) : (Color(hex: "#791F1F") ?? Color.red)

        let lightColors: [(bg: Color, text: Color)] = [
            (Color(hex: "#E6F1FB") ?? .blue, Color(hex: "#0C447C") ?? .blue),
            (Color(hex: "#EAF3DE") ?? .green, Color(hex: "#27500A") ?? .green),
            (Color(hex: "#EEEDFE") ?? .purple, Color(hex: "#3C3489") ?? .purple),
            (Color(hex: "#FAEEDA") ?? .orange, Color(hex: "#633806") ?? .orange),
            (Color(hex: "#E1F5EE") ?? .teal, Color(hex: "#085041") ?? .teal),
            (Color(hex: "#FBEAF0") ?? .pink, Color(hex: "#72243E") ?? .pink),
            (Color(hex: "#FAECE7") ?? .red, Color(hex: "#712B13") ?? .red),
            (Color(hex: "#F1EFE8") ?? .gray, Color(hex: "#444441") ?? .gray),
        ]
        let darkColors: [(bg: Color, text: Color)] = [
            (Color(hex: "#0C447C") ?? .blue, Color(hex: "#B5D4F4") ?? .blue),
            (Color(hex: "#27500A") ?? .green, Color(hex: "#C0DD97") ?? .green),
            (Color(hex: "#3C3489") ?? .purple, Color(hex: "#CECBF6") ?? .purple),
            (Color(hex: "#633806") ?? .orange, Color(hex: "#FAC775") ?? .orange),
            (Color(hex: "#085041") ?? .teal, Color(hex: "#9FE1CB") ?? .teal),
            (Color(hex: "#72243E") ?? .pink, Color(hex: "#F4C0D1") ?? .pink),
            (Color(hex: "#712B13") ?? .red, Color(hex: "#F5C4B3") ?? .red),
            (Color(hex: "#444441") ?? .gray, Color(hex: "#D3D1C7") ?? .gray),
        ]

        VStack(alignment: .leading, spacing: 6) {
            // 1. Dòng tiêu đề: "Tuần dd/MM – dd/MM" kèm nút ‹ ›
            HStack {
                Text("‹")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textSecondary)
                    .frame(width: 24, height: 20)
                Spacer()
                Text(viewModel.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("›")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textSecondary)
                    .frame(width: 24, height: 20)
            }

            // 2. Dải 7 ngày
            HStack(spacing: 0) {
                ForEach(0..<viewModel.daysStrip.count, id: \.self) { i in
                    let day = viewModel.daysStrip[i]
                    VStack(spacing: 4) {
                        Text(day.weekday)
                            .font(.system(size: 11, weight: day.isToday ? .semibold : .regular))
                            .foregroundColor(day.isToday ? accentColor : textSecondary)

                        if day.isToday {
                            Text(day.countText)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(accentOn)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(accentColor))
                        } else {
                            Text(day.countText)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(day.count > 0 ? textPrimary : textDimmed)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()
                .background(borderColor)

            // 3. Danh sách chi tiết hoặc Empty State
            if !viewModel.hasSnapshot {
                Spacer()
                HStack {
                    Spacer()
                    Text(viewModel.authMessage ?? "Đăng nhập để xem lịch")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(textSecondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.items) { item in
                        switch item {
                        case .header(let group):
                            Text(group.headerTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(group.isToday ? accentColor : textPrimary)
                                .padding(.top, 4)
                        case .session(let s):
                            let barColor: Color = {
                                if s.isToday && s.isPast {
                                    return isDark ? (Color(hex: "#444441") ?? .gray) : (Color(hex: "#D3D1C7") ?? .gray)
                                } else if s.isExam {
                                    return Color(hex: "#E24B4A") ?? .red
                                } else {
                                    let palette = isDark ? darkColors : lightColors
                                    let safeIdx = min(max(s.colorIndex, 0), 7)
                                    return palette[safeIdx].text
                                }
                            }()
                            let titleColor: Color = {
                                if s.isToday && s.isPast {
                                    return textDimmed
                                } else if s.isExam {
                                    return examColor
                                } else {
                                    return textPrimary
                                }
                            }()

                            HStack(alignment: .center, spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor)
                                    .frame(width: 3, height: 14)

                                Text(s.timeStr)
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor((s.isToday && s.isPast) ? textDimmed : textSecondary)
                                    .frame(width: 34, alignment: .leading)

                                Text(s.displayTitle)
                                    .font(.system(size: 11, weight: s.isExam ? .semibold : .regular))
                                    .foregroundColor(titleColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Spacer()

                                if !s.roomStr.isEmpty {
                                    Text(s.roomStr)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor((s.isToday && s.isPast) ? textDimmed : textSecondary)
                                }
                            }
                            .frame(height: 19)
                        case .emptyDays(let empty):
                            Text(empty.displayTitle)
                                .font(.system(size: 11, weight: .regular))
                                .italic()
                                .foregroundColor(textDimmed)
                                .padding(.top, 2)
                        }
                    }
                }

                if let footer = viewModel.footerText {
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Text(footer)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textSecondary)
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bgColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 0.5)
        )
    }
}

// MARK: - SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Bước 6: Lock Screen Views (iOS 16+)

struct LockScreenRectangularSwiftUIView: View {
    let model: LockScreenRectangularViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.line1)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            if !model.line2.isEmpty {
                Text(model.line2)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(1)
            }
            if let line3 = model.line3, !line3.isEmpty {
                Text(line3)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetAccentable()
        .privacySensitive()
    }
}

struct LockScreenCircularSwiftUIView: View {
    let model: LockScreenCircularViewModel

    var body: some View {
        Gauge(value: model.progress, in: 0.0...1.0) {
            Image(systemName: "calendar")
        } currentValueLabel: {
            Text(model.centerText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .minimumScaleFactor(0.7)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .privacySensitive()
    }
}

struct LockScreenInlineSwiftUIView: View {
    let model: LockScreenInlineViewModel

    var body: some View {
        Text(model.text)
            .privacySensitive()
    }
}

struct ScheduleWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ScheduleWidgetEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularSwiftUIView(model: entry.lockScreenRectangular)

        case .accessoryCircular:
            LockScreenCircularSwiftUIView(model: entry.lockScreenCircular)

        case .accessoryInline:
            LockScreenInlineSwiftUIView(model: entry.lockScreenInline)

        case .systemSmall:
            // 2x2 Hôm nay View (SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3.1)
            Today2x2SwiftUIView(viewModel: entry.today2x2)

        case .systemMedium:
            if entry.layoutMode == "month_today" {
                MonthToday4x2SwiftUIView(viewModel: entry.monthToday4x2)
            } else {
                ThreeDays4x2SwiftUIView(viewModel: entry.threeDays4x2)
            }

        case .systemLarge:
            // 4x4 Weekly Widget theo SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Bước 5
            Weekly4x4SwiftUIView(viewModel: entry.weekly4x4)

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
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline
        ])
    }
}
