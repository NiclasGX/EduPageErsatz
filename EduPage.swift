import Foundation

struct SchoolEvent: Identifiable {
    let id = UUID()
    
    let summary: String
    let start: String
    let end: String
    
    let location: String
    let description: String
    
    let date: Date?
    let period: Int?
    
    let teacher: String
    let oldTeacher: String?
    let newTeacher: String?
    
    let cancelled: Bool
    let substitution: Bool
    let teacherChangeKnown: Bool
}

enum SchoolData {
    
    static let times: [(start: String, end: String)] = [
        ("07:10", "07:55"),
        ("08:05", "08:50"),
        ("08:50", "09:35"),
        ("09:55", "10:40"),
        ("10:50", "11:35"),
        ("11:45", "12:30"),
        ("12:35", "13:20"),
        ("13:25", "14:10"),
        ("14:15", "15:00")
    ]
    
    // MARK: Text bereinigen
    
    static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: ICS-Datum
    
    // Wichtig:
    // Hier kommt normalerweise bereits NUR
    // "20260818T051000Z" an.
    //
    // Die Funktion kann aber auch
    // "DTSTART:20260818T051000Z" verarbeiten.
    
    static func rawDateValue(_ value: String) -> String {
        
        if let colon = value.firstIndex(of: ":") {
            return String(
                value[value.index(after: colon)...]
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        }
        
        return value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }
    
    static func parseDate(_ value: String) -> Date? {
        
        let raw = rawDateValue(value)
        
        let formatter = DateFormatter()
        
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        
        if raw.hasSuffix("Z") {
            
            formatter.timeZone = TimeZone(
                secondsFromGMT: 0
            )
            
            formatter.dateFormat =
            "yyyyMMdd'T'HHmmss'Z'"
            
        } else {
            
            formatter.timeZone = TimeZone(
                identifier: "Europe/Berlin"
            )
            
            formatter.dateFormat =
            "yyyyMMdd'T'HHmmss"
        }
        
        return formatter.date(from: raw)
    }
    
    // MARK: Deutsche Uhrzeit
    
    static func germanTime(_ value: String) -> String? {
        
        let raw = rawDateValue(value)
        
        let formatter = DateFormatter()
        
        formatter.locale = Locale(
            identifier: "en_US_POSIX"
        )
        
        if raw.hasSuffix("Z") {
            
            formatter.timeZone = TimeZone(
                secondsFromGMT: 0
            )
            
            formatter.dateFormat =
            "yyyyMMdd'T'HHmmss'Z'"
            
        } else {
            
            formatter.timeZone = TimeZone(
                identifier: "Europe/Berlin"
            )
            
            formatter.dateFormat =
            "yyyyMMdd'T'HHmmss"
        }
        
        guard let date = formatter.date(
            from: raw
        ) else {
            return nil
        }
        
        let output = DateFormatter()
        
        output.locale = Locale(
            identifier: "en_US_POSIX"
        )
        
        output.timeZone = TimeZone(
            identifier: "Europe/Berlin"
        )
        
        output.dateFormat = "HH:mm"
        
        return output.string(
            from: date
        )
    }
    
    // MARK: Minuten
    
    static func minutes(_ value: String) -> Int? {
        
        let parts = value.split(
            separator: ":"
        )
        
        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1])
        else {
            return nil
        }
        
        return hour * 60 + minute
    }
    
    // MARK: Stunde bestimmen
    
    static func determinePeriod(
        start: String,
        end: String
    ) -> Int? {
        
        guard
            let actualStart = germanTime(start)
                .flatMap(minutes),
            
                let actualEnd = germanTime(end)
                .flatMap(minutes)
        else {
            return nil
        }
        
        for index in times.indices {
            
            guard
                let lessonStart =
                    minutes(times[index].start),
                
                    let lessonEnd =
                    minutes(times[index].end)
            else {
                continue
            }
            
            if actualStart == lessonStart &&
                actualEnd == lessonEnd {
                
                return index + 1
            }
        }
        
        return nil
    }
    
    // MARK: Lehrer
    
    static func extractTeacher(
        _ description: String
    ) -> (
        teacher: String,
        oldTeacher: String?,
        newTeacher: String?,
        known: Bool
    ) {
        
        let cleaned = clean(description)
        
        let lines = cleaned.components(
            separatedBy: .newlines
        )
        
        guard
            let lastLine = lines.last?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            !lastLine.isEmpty
        else {
            return ("", nil, nil, false)
        }
        
        // Beispiel:
        //
        // REIC -> KRET
        //
        // oder:
        //
        // REIC -> X
        
        if lastLine.contains("->") {
            
            let parts = lastLine.components(
                separatedBy: "->"
            )
            
            if parts.count >= 2 {
                
                let oldTeacher = parts[0]
                    .trimmingCharacters(
                        in: .whitespaces
                    )
                
                let newTeacher = parts[1]
                    .trimmingCharacters(
                        in: .whitespaces
                    )
                
                let known =
                !newTeacher.isEmpty &&
                newTeacher.uppercased() != "X"
                
                return (
                    known ? newTeacher : oldTeacher,
                    oldTeacher,
                    known ? newTeacher : nil,
                    known
                )
            }
        }
        
        return (
            lastLine,
            nil,
            nil,
            true
        )
    }
    
    // MARK: Event
    
    static func makeEvent(
        _ data: [String: String]
    ) -> SchoolEvent {
        
        let summary = clean(
            data["SUMMARY"] ?? "Unbekannt"
        )
        
        let start =
        data["DTSTART"] ?? ""
        
        let end =
        data["DTEND"] ?? ""
        
        let location = clean(
            data["LOCATION"] ?? ""
        )
        
        let description = clean(
            data["DESCRIPTION"] ?? ""
        )
        
        let teacherData =
        extractTeacher(description)
        
        let fullText = (
            summary + " " + description
        ).lowercased()
        
        let cancelled =
        fullText.contains("ausfall") ||
        fullText.contains("entfällt") ||
        fullText.contains("entfaellt") ||
        fullText.contains("cancel")
        
        let substitution =
        teacherData.oldTeacher != nil
        
        return SchoolEvent(
            summary: summary,
            start: start,
            end: end,
            location: location,
            description: description,
            date: parseDate(start),
            period: determinePeriod(
                start: start,
                end: end
            ),
            teacher: teacherData.teacher,
            oldTeacher: teacherData.oldTeacher,
            newTeacher: teacherData.newTeacher,
            cancelled: cancelled,
            substitution: substitution,
            teacherChangeKnown: teacherData.known
        )
    }
}

// MARK: - Gelernter Stundenplan

private struct LearnedLesson: Codable {
    let weekday: Int
    let period: Int
    let summary: String
    let teacher: String
    let location: String
}

private let learnedScheduleKey = "learnedSchedule"

func resetLearnedSchedule() {
    UserDefaults.standard.removeObject(forKey: learnedScheduleKey)
}

private func addLearnedCancellations(
    to events: [SchoolEvent]
) -> [SchoolEvent] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    
    let learned = loadLearnedLessons()
    let freeDays = Set(
        (UserDefaults.standard.string(forKey: "schoolFreeDays") ?? "")
            .split(separator: ",")
            .map(String.init)
    )
    let lessonDays = Set(events.compactMap { event -> Date? in
        guard event.period != nil, let date = event.date else {
            return nil
        }
        return calendar.startOfDay(for: date)
    })
    let occupiedSlots = Set(events.compactMap { event -> String? in
        guard let date = event.date, let period = event.period else {
            return nil
        }
        return learnedSlotKey(calendar.startOfDay(for: date), period, calendar)
    })
    
    var detectedCancellations: [SchoolEvent] = []
    
    for day in lessonDays where !freeDays.contains(learnedDateKey(day, calendar)) {
        let weekday = calendar.component(.weekday, from: day)
        
        for lesson in learned where lesson.weekday == weekday {
            guard !occupiedSlots.contains(learnedSlotKey(day, lesson.period, calendar)) else {
                continue
            }
            
            detectedCancellations.append(
                SchoolEvent(
                    summary: lesson.summary,
                    start: "",
                    end: "",
                    location: lesson.location,
                    description: "Automatisch erkannt: Stunde fehlt im Kalender.",
                    date: day,
                    period: lesson.period,
                    teacher: lesson.teacher,
                    oldTeacher: nil,
                    newTeacher: nil,
                    cancelled: true,
                    substitution: false,
                    teacherChangeKnown: false
                )
            )
        }
    }
    
    rememberLessons(events, calendar)
    
    return (events + detectedCancellations).sorted {
        ($0.date ?? .distantPast) < ($1.date ?? .distantPast)
    }
}

private func loadLearnedLessons() -> [LearnedLesson] {
    guard let data = UserDefaults.standard.data(forKey: learnedScheduleKey),
          let lessons = try? JSONDecoder().decode([LearnedLesson].self, from: data)
    else {
        return []
    }
    return lessons
}

private func rememberLessons(
    _ events: [SchoolEvent],
    _ calendar: Calendar
) {
    var lessons: [String: LearnedLesson] = [:]
    
    for savedLesson in loadLearnedLessons() {
        lessons["\(savedLesson.weekday)-\(savedLesson.period)"] = savedLesson
    }
    
    for event in events {
        guard !event.cancelled, let date = event.date, let period = event.period else {
            continue
        }
        
        let weekday = calendar.component(.weekday, from: date)
        lessons["\(weekday)-\(period)"] = LearnedLesson(
            weekday: weekday,
            period: period,
            summary: event.summary,
            teacher: event.teacher,
            location: event.location
        )
    }
    
    if let data = try? JSONEncoder().encode(Array(lessons.values)) {
        UserDefaults.standard.set(data, forKey: learnedScheduleKey)
    }
}

private func learnedSlotKey(
    _ day: Date,
    _ period: Int,
    _ calendar: Calendar
) -> String {
    "\(learnedDateKey(day, calendar))-\(period)"
}

private func learnedDateKey(
    _ date: Date,
    _ calendar: Calendar
) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
        format: "%04d-%02d-%02d",
        components.year ?? 0,
        components.month ?? 0,
        components.day ?? 0
    )
}

// MARK: - EduPage laden

func loadEduPage(urlString: String) async throws -> [SchoolEvent] {
    
    guard let calendarURL = URL(string: urlString),
          let scheme = calendarURL.scheme?.lowercased(),
          scheme == "https" || scheme == "http"
    else {
        throw URLError(.badURL)
    }
    
    var request = URLRequest(
        url: calendarURL
    )
    
    request.timeoutInterval = 20
    
    request.setValue(
        "text/calendar,*/*",
        forHTTPHeaderField: "Accept"
    )
    
    let (data, response) =
    try await URLSession.shared.data(
        for: request
    )
    
    guard
        let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode)
    else {
        throw URLError(
            .badServerResponse
        )
    }
    
    guard let text = String(
        data: data,
        encoding: .utf8
    ) else {
        throw URLError(
            .cannotDecodeContentData
        )
    }
    
    // MARK: ICS-Zeilen
    
    var lines: [String] = []
    
    for rawLine in text.components(
        separatedBy: .newlines
    ) {
        
        if rawLine.hasPrefix(" ")
            || rawLine.hasPrefix("\t") {
            
            if !lines.isEmpty {
                
                lines[lines.count - 1] +=
                String(
                    rawLine.dropFirst()
                )
            }
            
        } else {
            
            lines.append(rawLine)
        }
    }
    
    // MARK: Events
    
    var events: [SchoolEvent] = []
    
    var currentEvent:
    [String: String]? = nil
    
    for line in lines {
        
        if line == "BEGIN:VEVENT" {
            
            currentEvent = [:]
            continue
        }
        
        if line == "END:VEVENT" {
            
            if let currentEvent {
                
                events.append(
                    SchoolData.makeEvent(
                        currentEvent
                    )
                )
            }
            
            currentEvent = nil
            continue
        }
        
        guard currentEvent != nil else {
            continue
        }
        
        guard let colon =
                line.firstIndex(of: ":")
        else {
            continue
        }
        
        var key = String(
            line[..<colon]
        )
        
        let value = String(
            line[
                line.index(after: colon)...
            ]
        )
        
        if let semicolon =
            key.firstIndex(of: ";") {
            
            key = String(
                key[..<semicolon]
            )
        }
        
        currentEvent?[key] = value
    }
    
    // Nur Montag bis Freitag
    
    let calendar = Calendar.current
    
    let weekdayEvents = events
        .filter { event in
            
            guard let date = event.date else {
                return false
            }
            
            let weekday =
            calendar.component(
                .weekday,
                from: date
            )
            
            return weekday >= 2 &&
            weekday <= 6
        }
    return addLearnedCancellations(to: weekdayEvents)
}
