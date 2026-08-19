import SwiftUI
import UIKit

struct PressableButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(
                .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

struct ContentView: View {

    @State private var showResetLearnedConfirmation = false
    @State private var showResetAppConfirmation = false
    @State private var autoRefreshTask: Task<Void, Never>?
    @State private var events: [SchoolEvent] = []
    @State private var selectedDate = Date()
    @State private var mode: ViewMode = .week
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var reloading = false
    @State private var showingSettings = false
    @State private var newSchoolFreeDay = Date()

    @AppStorage("calendarURL") private var calendarURL = ""
    @AppStorage("normalLessonColor") private var normalLessonColor = "#132033"
    @AppStorage("emptyLessonColor") private var emptyLessonColor = "#0C111B"
    @AppStorage("freeLessonColor") private var freeLessonColor = "#182230"
    @AppStorage("cancelledLessonColor") private var cancelledLessonColor = "#7A121A"
    @AppStorage("substitutionLessonColor") private var substitutionLessonColor = "#0B6E8A"
    @AppStorage("unknownTeacherColor") private var unknownTeacherColor = "#A15416"
    @AppStorage("schoolFreeColor") private var schoolFreeColor = "#6B4A0D"
    @AppStorage("backgroundStartColor") private var backgroundStartColor = "#07111F"
    @AppStorage("backgroundEndColor") private var backgroundEndColor = "#172B4D"
    @AppStorage("primaryTextColor") private var primaryTextColor = "#F6F8FF"
    @AppStorage("secondaryTextColor") private var secondaryTextColor = "#AAB7D1"
    @AppStorage("todayColor") private var todayColor = "#4EA5FF"
    @AppStorage("tomorrowColor") private var tomorrowColor = "#A78BFA"
    @AppStorage("currentTimeColor") private var currentTimeColor = "#FF4D6D"
    @AppStorage("pauseColor") private var pauseColor = "#74829E"
    @AppStorage("schoolFreeDays") private var schoolFreeDays = ""

    enum ViewMode {
        case week
        case day
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                background

                VStack(spacing: 0) {
                    let compact = geometry.size.width < 600
                        || geometry.size.height < 600

                    header(compact: compact)

                    if mode == .week && !compact {
                        weekView(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                    } else {
                        dayView(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                    }
                }

                if loading {
                    loadingView
                }

                if let message = errorMessage {
                    if message.contains("NSURLErrorDomain error -1000") {
                        errorView("Profil-URL nicht angegeben!")
                    } else {
                        errorView(message)
                    }
                }
            }
        }
        
        .task {
            if !calendarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await reload()
            } else {
                loading = false
            }

            autoRefreshTask?.cancel()

            autoRefreshTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(
                        for: .seconds(15 * 60)
                    )

                    if Task.isCancelled {
                        break
                    }

                    if !calendarURL
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty {

                        await reload()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            settingsView
        }

    }

    // MARK: - Hintergrund

    private var background: some View {
        LinearGradient(
            colors: [
                Color(hex: backgroundStartColor),
                Color(hex: backgroundEndColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private func header(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 12) {

            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text(
                    mode == .week && !compact
                    ? "Stundenplan"
                    : dayTitle
                )
                .font(
                    .system(
                        size: compact ? 22 : 29,
                        weight: .bold
                    )
                )
                .foregroundStyle(Color(hex: primaryTextColor))

                Text(
                    mode == .week && !compact
                    ? weekTitle
                    : fullDate
                )
                .font(
                    .system(
                        size: 14,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color(hex: secondaryTextColor)
                )
            }

            Spacer()

            if !compact {
                HStack(spacing: 3) {

                    modeButton(
                        title: "Woche",
                        selected: mode == .week
                    ) {
                        mode = .week
                    }

                    modeButton(
                        title: "Tag",
                        selected: mode == .day
                    ) {
                        mode = .day
                    }
                }
                .padding(4)
                .background(
                    Capsule()
                        .fill(
                            .white.opacity(0.07)
                        )
                )
            }

            navigationButton("‹") {
                moveBackward(byDay: compact)
            }

            navigationButton("›") {
                moveForward(byDay: compact)
            }

            Button {
                Task {
                    await reload()
                }
            } label: {
                ZStack {
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                    .fill(
                        .white.opacity(0.07)
                    )

                    if reloading {
                        ProgressView()
                            .tint(Color(hex: primaryTextColor))
                    } else {
                        Image(
                            systemName: "arrow.clockwise"
                        )
                        .font(
                            .system(
                                size: 16,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(
                            Color(hex: primaryTextColor)
                        )
                    }
                }
                .frame(
                    width: 42,
                    height: 40
                )
            }
            .buttonStyle(.plain)
            .disabled(reloading)

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: primaryTextColor))
                    .frame(width: 42, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.07))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, compact ? 12 : 24)
        .padding(.top, compact ? 10 : 16)
        .padding(.bottom, compact ? 6 : 10)
    }

    private func modeButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            Text(title)
                .font(
                    .system(
                        size: 14,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    selected
                    ? .white
                    : .white.opacity(0.4)
                )
                .padding(
                    .horizontal,
                    17
                )
                .padding(
                    .vertical,
                    8
                )
                .background {
                    if selected {
                        Capsule()
                            .fill(
                                .white.opacity(0.15)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func navigationButton(
        _ text: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            Text(text)
                .font(
                    .system(
                        size: 27,
                        weight: .medium
                    )
                )
                .foregroundStyle(Color(hex: primaryTextColor))
                .frame(
                    width: 40,
                    height: 40
                )
                .background(
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                    .fill(
                        .white.opacity(0.06)
                    )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Wochenansicht

    private func weekView(
        width: CGFloat,
        height: CGFloat
    ) -> some View {

        let days = weekDays

        let pauseHeight: CGFloat = height < 600 ? 8 : 12
        let rowHeight = scheduleRowHeight(
            totalHeight: height - 145,
            pauseHeight: pauseHeight
        )
        let gridHeight = scheduleGridHeight(
            rowHeight: rowHeight,
            pauseHeight: pauseHeight
        )

        return VStack(spacing: 0) {

            HStack(spacing: 6) {

                Color.clear
                    .frame(width: 67)

                ForEach(
                    days,
                    id: \.self
                ) { day in
                    dayHeader(day)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            ZStack(alignment: .topLeading) {
                VStack(spacing: 4) {

                    ForEach(
                        1...9,
                        id: \.self
                    ) { period in

                        weekRow(
                            period: period,
                            days: days,
                            height: rowHeight
                        )

                        if hasVisualGap(after: period) {
                            weekBreakRow(
                                after: period,
                                height: gapHeight(
                                    after: period,
                                    pauseHeight: pauseHeight
                                )
                            )
                        }
                    }
                }

                currentTimeMarker(height: gridHeight)
            }
            .padding(.horizontal, 18)
        }
    }

    private func weekRow(
        period: Int,
        days: [Date],
        height: CGFloat
    ) -> some View {

        HStack(spacing: 6) {

            hourLabel(period)
                .frame(
                    width: 67,
                    height: height
                )

            ForEach(
                days,
                id: \.self
            ) { day in

                lessonCell(
                    event: eventFor(
                        day: day,
                        period: period
                    ),
                    day: day,
                    period: period
                )
                .frame(
                    maxWidth: .infinity
                )
                .frame(height: height)
            }
        }
    }

    // MARK: - Tagesansicht

    private func dayView(
        width: CGFloat,
        height: CGFloat
    ) -> some View {

        let pauseHeight: CGFloat = height < 600 ? 8 : 12
        let bannerHeight: CGFloat = isSchoolFree(selectedDate) ? 42 : 0

        let rowHeight = scheduleRowHeight(
            totalHeight:
                height
                - (height < 600 ? 65 : 105)
                - bannerHeight,
            pauseHeight: pauseHeight
        )

        let gridHeight = scheduleGridHeight(
            rowHeight: rowHeight,
            pauseHeight: pauseHeight
        )

        return VStack(spacing: 4) {

            if isSchoolFree(selectedDate) {
                schoolFreeBanner
            }

            ZStack(alignment: .topLeading) {

                VStack(spacing: 4) {

                    ForEach(
                        1...9,
                        id: \.self
                    ) { period in

                        HStack(spacing: 9) {

                            hourLabel(period)
                                .frame(
                                    width: 75,
                                    height: rowHeight
                                )

                            lessonCell(
                                event: eventFor(
                                    day: selectedDate,
                                    period: period
                                ),
                                day: selectedDate,
                                period: period
                            )
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(
                                height: rowHeight
                            )
                        }

                        if hasVisualGap(after: period) {
                            dayBreakRow(
                                after: period,
                                height: gapHeight(
                                    after: period,
                                    pauseHeight: pauseHeight
                                )
                            )
                        }
                    }
                }

                currentTimeMarker(height: gridHeight)
            }
        }
        .padding(
            .horizontal,
            width < 600 ? 16 : 30
        )
    }

    private func scheduleRowHeight(
        totalHeight: CGFloat,
        pauseHeight: CGFloat
    ) -> CGFloat {

        let breakCount =
            SchoolData.times.indices
                .filter {
                    hasVisualGap(after: $0 + 1)
                }
                .count

        let verticalSpacing =
            CGFloat(
                SchoolData.times.count
                + breakCount
                - 1
            ) * 4

        let gapHeights =
            SchoolData.times.indices
                .filter {
                    hasVisualGap(after: $0 + 1)
                }
                .reduce(CGFloat.zero) {
                    total,
                    index in
                    total
                    + gapHeight(
                        after: index + 1,
                        pauseHeight: pauseHeight
                    )
                }

        let remaining =
            totalHeight
            - gapHeights
            - verticalSpacing

        return max(
            16,
            min(
                76,
                remaining
                / CGFloat(
                    SchoolData.times.count
                )
            )
        )
    }

    private func scheduleGridHeight(
        rowHeight: CGFloat,
        pauseHeight: CGFloat
    ) -> CGFloat {

        let breakCount =
            SchoolData.times.indices
                .filter {
                    hasVisualGap(after: $0 + 1)
                }
                .count

        let spacing =
            CGFloat(
                SchoolData.times.count
                + breakCount
                - 1
            ) * 4

        let gapHeights =
            SchoolData.times.indices
                .filter {
                    hasVisualGap(after: $0 + 1)
                }
                .reduce(CGFloat.zero) {
                    total,
                    index in
                    total
                    + gapHeight(
                        after: index + 1,
                        pauseHeight: pauseHeight
                    )
                }

        return
            CGFloat(SchoolData.times.count)
            * rowHeight
            + gapHeights
            + spacing
    }

    @ViewBuilder
    private func currentTimeMarker(
        height: CGFloat
    ) -> some View {

        TimelineView(
            .periodic(
                from: .now,
                by: 60
            )
        ) { context in

            if let progress =
                schoolDayProgress(
                    for: context.date
                ) {

                let position =
                    height * progress

                ZStack(
                    alignment: .topLeading
                ) {

                    Rectangle()
                        .fill(
                            Color(
                                hex: currentTimeColor
                            )
                        )
                        .frame(
                            width: 3,
                            height: position
                        )

                    Text(
                        currentTimeText(
                            context.date
                        )
                    )
                    .font(
                        .system(
                            size: 8,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color(
                            hex: currentTimeColor
                        )
                    )
                    .padding(
                        .leading,
                        7
                    )
                    .offset(
                        y: max(
                            0,
                            position - 7
                        )
                    )
                }
                .frame(
                    width: 67,
                    height: height,
                    alignment: .topLeading
                )
            }
        }
    }

    private func schoolDayProgress(
        for date: Date
    ) -> CGFloat? {

        let formatter =
            DateFormatter()

        formatter.timeZone =
            TimeZone(
                identifier:
                    "Europe/Berlin"
            )

        formatter.dateFormat =
            "HH:mm"

        guard
            let now =
                SchoolData.minutes(
                    formatter.string(
                        from: date
                    )
                ),

            let start =
                SchoolData.minutes(
                    SchoolData.times.first?.start
                    ?? ""
                ),

            let end =
                SchoolData.minutes(
                    SchoolData.times.last?.end
                    ?? ""
                ),

            now >= start,
            now <= end
        else {
            return nil
        }

        return CGFloat(
            now - start
        )
        / CGFloat(
            end - start
        )
    }

    private func currentTimeText(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.timeZone =
            TimeZone(
                identifier:
                    "Europe/Berlin"
            )

        formatter.dateFormat =
            "HH:mm"

        return formatter.string(
            from: date
        )
    }

    private func breakDuration(
        after period: Int
    ) -> Int? {

        guard
            period > 0,
            period < SchoolData.times.count,

            let end =
                SchoolData.minutes(
                    SchoolData
                        .times[period - 1]
                        .end
                ),

            let start =
                SchoolData.minutes(
                    SchoolData
                        .times[period]
                        .start
                )
        else {
            return nil
        }

        let duration =
            start - end

        return duration > 0
            ? duration
            : nil
    }

    private func hasVisualGap(
        after period: Int
    ) -> Bool {

        breakDuration(
            after: period
        ) != nil
        || period == 2
    }

    private func gapHeight(
        after period: Int,
        pauseHeight: CGFloat
    ) -> CGFloat {

        breakDuration(
            after: period
        ) == nil
        ? 5
        : pauseHeight
    }

    private func weekBreakRow(
        after period: Int,
        height: CGFloat
    ) -> some View {

        HStack(spacing: 6) {

            Color.clear
                .frame(width: 67)

            if let duration =
                breakDuration(
                    after: period
                ) {

                Text(
                    "Pause · \(duration) Min."
                )
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color(
                        hex: pauseColor
                    )
                )
                .frame(
                    maxWidth: .infinity
                )

            } else {

                Color.clear
                    .frame(
                        maxWidth: .infinity
                    )
            }
        }
        .frame(height: height)
    }

    private func dayBreakRow(
        after period: Int,
        height: CGFloat
    ) -> some View {

        HStack(spacing: 9) {

            if let duration =
                breakDuration(
                    after: period
                ) {

                Text("Pause")
                    .font(
                        .system(
                            size: 9,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        Color(
                            hex: pauseColor
                        )
                    )
                    .frame(
                        width: 75,
                        alignment: .trailing
                    )

                Text(
                    "\(duration) Minuten"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    Color(
                        hex: pauseColor
                    )
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

            } else {

                Color.clear
                    .frame(
                        maxWidth: .infinity
                    )
            }
        }
        .frame(height: height)
    }

    // MARK: - Stundenlabel

    private func hourLabel(
        _ period: Int
    ) -> some View {

        let current =
            isCurrentPeriod(period)

        let time =
            SchoolData
                .times[period - 1]

        return VStack(
            alignment: .leading,
            spacing: 1
        ) {

            HStack(spacing: 5) {

                Circle()
                    .fill(
                        current
                        ? Color(
                            hex: todayColor
                        )
                        : .clear
                    )
                    .frame(
                        width: 7,
                        height: 7
                    )

                Text(
                    "\(period)."
                )
                .font(
                    .system(
                        size: 16,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    current
                    ? Color(
                        hex: todayColor
                    )
                    : Color(
                        hex: primaryTextColor
                    )
                )
                .frame(
                    width: 25,
                    alignment: .trailing
                )
            }

            Text(
                "\(time.start) – \(time.end)"
            )
            .font(
                .system(
                    size: 9,
                    weight: .medium
                )
            )
            .foregroundStyle(
                Color(
                    hex: secondaryTextColor
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
        }
    }

    // MARK: - Stundenfeld

    private func lessonCell(
        event: SchoolEvent?,
        day: Date,
        period: Int
    ) -> some View {

        let isFree =
            event == nil
            && shouldShowFreePeriod(
                day: day,
                period: period
            )

        let isEmpty =
            event == nil
            && !isFree

        return ZStack(
            alignment: .leading
        ) {

            if !isEmpty {

                RoundedRectangle(
                    cornerRadius: 12
                )
                .fill(
                    isFree
                    ? Color(
                        hex: freeLessonColor
                    )
                    : cellBackground(event)
                )

                RoundedRectangle(
                    cornerRadius: 12
                )
                .stroke(
                    .white.opacity(
                        event == nil
                        ? 0.025
                        : 0.08
                    ),
                    lineWidth: 1
                )
            }

            if let event = event {

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

                    HStack(spacing: 5) {

                        Text(event.summary)
                            .font(
                                .system(
                                    size: 14,
                                    weight: .bold
                                )
                            )
                            .foregroundStyle(
                                Color(
                                    hex:
                                        primaryTextColor
                                )
                            )
                            .lineLimit(1)

                        Spacer(
                            minLength: 0
                        )

                        statusBadge(event)
                    }

                    if let oldTeacher =
                        event.oldTeacher,
                       let newTeacher =
                        event.newTeacher {

                        HStack(spacing: 4) {

                            Text(oldTeacher)
                                .strikethrough()
                                .foregroundStyle(
                                    .white.opacity(
                                        0.35
                                    )
                                )

                            Image(
                                systemName:
                                    "arrow.right"
                            )
                            .font(
                                .system(
                                    size: 8
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(
                                    0.45
                                )
                            )

                            Text(newTeacher)
                                .foregroundStyle(
                                    .white.opacity(
                                        0.9
                                    )
                                )
                        }
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold
                            )
                        )

                    } else if !event.teacher.isEmpty {

                        Text(event.teacher)
                            .font(
                                .system(
                                    size: 11,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(
                                .white.opacity(
                                    0.7
                                )
                            )
                            .lineLimit(1)
                    }

                    if !event.location.isEmpty {

                        HStack(spacing: 4) {

                            Image(
                                systemName:
                                    "door.left.hand.open"
                            )
                            .font(
                                .system(
                                    size: 8
                                )
                            )

                            Text(event.location)
                        }
                        .font(
                            .system(
                                size: 9,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            .white.opacity(
                                0.4
                            )
                        )
                    }
                }
                .padding(
                    .horizontal,
                    10
                )
                .padding(
                    .vertical,
                    5
                )

            } else if isFree {

                HStack(spacing: 8) {

                    Image(
                        systemName:
                            "cup.and.saucer.fill"
                    )
                    .foregroundStyle(
                        Color(
                            hex:
                                secondaryTextColor
                        )
                    )

                    Text("Freistunde")
                        .font(
                            .system(
                                size: 13,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(
                            Color(
                                hex:
                                    secondaryTextColor
                            )
                        )
                }
                .padding(
                    .horizontal,
                    11
                )
            }

            if isCurrentPeriod(period)
                && isSameDay(
                    day,
                    Date()
                ) {

                HStack(spacing: 0) {

                    Rectangle()
                        .fill(
                            Color(
                                hex:
                                    todayColor
                            )
                        )
                        .frame(width: 4)

                    Spacer()
                }
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                )
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12
            )
        )
    }

    // MARK: - Status

    @ViewBuilder
    private func statusBadge(
        _ event: SchoolEvent
    ) -> some View {

        if event.cancelled {

            Text("AUSFALL")
                .font(
                    .system(
                        size: 8,
                        weight: .black
                    )
                )
                .foregroundStyle(.white)
                .padding(
                    .horizontal,
                    6
                )
                .padding(
                    .vertical,
                    3
                )
                .background(
                    Capsule()
                        .fill(
                            .red.opacity(0.8)
                        )
                )

        } else if event.substitution {

            Text(
                event.teacherChangeKnown
                ? "VERTRETUNG"
                : "LEHRER UNBEKANNT"
            )
            .font(
                .system(
                    size: 7,
                    weight: .black
                )
            )
            .foregroundStyle(.white)
            .padding(
                .horizontal,
                6
            )
            .padding(
                .vertical,
                3
            )
            .background(
                Capsule()
                    .fill(
                        event.teacherChangeKnown
                        ? .blue.opacity(0.8)
                        : .orange.opacity(0.8)
                    )
            )
        }
    }

    // MARK: - Farben

    private func cellBackground(
        _ event: SchoolEvent?
    ) -> Color {

        guard let event = event else {
            return Color(
                hex: emptyLessonColor
            )
        }

        if event.cancelled {
            return Color(
                hex: cancelledLessonColor
            )
        }

        if event.substitution
            && event.teacherChangeKnown {

            return Color(
                hex: substitutionLessonColor
            )
        }

        if event.substitution {

            return Color(
                hex: unknownTeacherColor
            )
        }

        return Color(
            hex: normalLessonColor
        )
    }

    // MARK: - Freistunden

    private func shouldShowFreePeriod(
        day: Date,
        period: Int
    ) -> Bool {

        guard
            period > 1,
            period < 9
        else {
            return false
        }

        let before =
            eventFor(
                day: day,
                period: period - 1
            )

        let after =
            eventFor(
                day: day,
                period: period + 1
            )

        return before != nil
            && after != nil
    }

    // MARK: - Aktuelle Stunde

    private func isCurrentPeriod(
        _ period: Int
    ) -> Bool {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.timeZone =
            TimeZone(
                identifier:
                    "Europe/Berlin"
            )

        formatter.dateFormat =
            "HH:mm"

        let current =
            formatter.string(
                from: Date()
            )

        let time =
            SchoolData
                .times[period - 1]

        return current >= time.start
            && current <= time.end
    }

    // MARK: - Woche

    private var weekDays: [Date] {

        let calendar =
            Calendar.current

        let weekday =
            calendar.component(
                .weekday,
                from: selectedDate
            )

        let mondayOffset =
            weekday == 1
            ? -6
            : 2 - weekday

        guard
            let monday =
                calendar.date(
                    byAdding: .day,
                    value: mondayOffset,
                    to: selectedDate
                )
        else {
            return []
        }

        return (0..<5).compactMap {
            calendar.date(
                byAdding: .day,
                value: $0,
                to: monday
            )
        }
    }

    // MARK: - Titel

    private var dayTitle: String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "de_DE"
            )

        formatter.dateFormat =
            "EEEE"

        return formatter
            .string(
                from: selectedDate
            )
            .capitalized
    }

    private var fullDate: String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "de_DE"
            )

        formatter.dateFormat =
            "dd. MMMM yyyy"

        return formatter.string(
            from: selectedDate
        )
    }

    private var weekTitle: String {

        guard
            let first =
                weekDays.first,
            let last =
                weekDays.last
        else {
            return ""
        }

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "de_DE"
            )

        formatter.dateFormat =
            "dd.MM."

        return
            "\(formatter.string(from: first)) – " +
            "\(formatter.string(from: last))"
    }

    // MARK: - Tageskopf

    private func dayHeader(
        _ date: Date
    ) -> some View {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "de_DE"
            )

        formatter.dateFormat =
            "EEE"

        let name =
            formatter
                .string(from: date)
                .uppercased()

        let number =
            Calendar.current.component(
                .day,
                from: date
            )

        let today =
            isSameDay(
                date,
                Date()
            )

        let tomorrow =
            Calendar.current
                .isDateInTomorrow(
                    date
                )

        let schoolFree =
            isSchoolFree(date)

        let markerColor =
            schoolFree
            ? Color(hex: schoolFreeColor)
            : (
                today
                ? Color(hex: todayColor)
                : Color(hex: tomorrowColor)
            )

        let label =
            schoolFree
            ? "FREI"
            : (
                today
                ? "HEUTE"
                : (
                    tomorrow
                    ? "MORGEN"
                    : name
                )
            )

        return VStack(spacing: 2) {

            Text(label)
                .font(
                    .system(
                        size: 10,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    today
                    || tomorrow
                    || schoolFree
                    ? markerColor
                    : Color(
                        hex:
                            secondaryTextColor
                    )
                )

            Text("\(number)")
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    schoolFree
                    ? Color(
                        hex:
                            schoolFreeColor
                    )
                    : (
                        (today || tomorrow)
                        ? markerColor
                        : Color(
                            hex:
                                primaryTextColor
                        )
                    )
                )
                .padding(
                    .horizontal,
                    today || tomorrow
                    ? 7
                    : 0
                )
                .background {
                    if today || tomorrow {
                        Capsule()
                            .fill(
                                markerColor
                                    .opacity(
                                        0.18
                                    )
                            )
                    }
                }

            if schoolFree {
                Text("SCHULFREI")
                    .font(
                        .system(
                            size: 7,
                            weight: .black
                        )
                    )
                    .foregroundStyle(
                        Color(
                            hex:
                                schoolFreeColor
                        )
                    )
            }
        }
        .frame(
            maxWidth: .infinity
        )
    }

    // MARK: - App Zurücksetzen

    func resetAllAppData() {
        UserDefaults.standard.removePersistentDomain(
            forName: Bundle.main.bundleIdentifier!
        )
    }

    // MARK: - Event suchen

    private func eventFor(
        day: Date,
        period: Int
    ) -> SchoolEvent? {

        events.first { event in

            guard
                let eventDate =
                    event.date
            else {
                return false
            }

            return isSameDay(
                eventDate,
                day
            )
            && event.period == period
        }
    }

    // MARK: - Datum

    private func isSameDay(
        _ first: Date,
        _ second: Date
    ) -> Bool {

        Calendar.current.isDate(
            first,
            inSameDayAs: second
        )
    }

    // MARK: - Navigation

    private func moveBackward(
        byDay: Bool = false
    ) {

        let component:
            Calendar.Component =
                mode == .week && !byDay
                ? .weekOfYear
                : .day

        selectedDate =
            Calendar.current.date(
                byAdding: component,
                value: -1,
                to: selectedDate
            )
            ?? selectedDate
    }

    private func moveForward(
        byDay: Bool = false
    ) {

        let component:
            Calendar.Component =
                mode == .week && !byDay
                ? .weekOfYear
                : .day

        selectedDate =
            Calendar.current.date(
                byAdding: component,
                value: 1,
                to: selectedDate
            )
            ?? selectedDate
    }

    // MARK: - Einstellungen

    private var settingsView: some View {

        NavigationStack {

            Form {

                Section("Kalender") {

                    TextField(
                        "Webcal-Link",
                        text: $calendarURL
                    )
                    .textInputAutocapitalization(
                        .never
                    )
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    Text(
                        "Der Link wird nur auf diesem iPad gespeichert."
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )
                }

                Section("Farbprofile") {

                    ForEach(
                        [
                            "Nachtblau",
                            "Nordlicht",
                            "Sonnenuntergang",
                            "Neon",
                            "Ozean",
                            "Wald",
                            "Lavendel",
                            "Eis",
                            "Vulkan",
                            "Mitternacht",
                            "Rosé",
                            "Cyber",
                            "Kupfer",
                            "Matrix"
                        ],
                        id: \.self
                    ) { profile in

                        Button(profile) {
                            applyColorProfile(profile)
                        }
                    }
                }

                Section("Farben: Oberfläche") {

                    colorPicker(
                        "Hintergrund oben",
                        value:
                            $backgroundStartColor
                    )

                    colorPicker(
                        "Hintergrund unten",
                        value:
                            $backgroundEndColor
                    )

                    colorPicker(
                        "Haupttext",
                        value:
                            $primaryTextColor
                    )

                    colorPicker(
                        "Neben-Text",
                        value:
                            $secondaryTextColor
                    )

                    colorPicker(
                        "Aktuelle Uhrzeit",
                        value:
                            $currentTimeColor
                    )

                    colorPicker(
                        "Pause",
                        value:
                            $pauseColor
                    )

                    colorPicker(
                        "Heute",
                        value:
                            $todayColor
                    )

                    colorPicker(
                        "Morgen",
                        value:
                            $tomorrowColor
                    )
                }

                Section("Farben: Stunden") {

                    colorPicker(
                        "Normale Stunde",
                        value:
                            $normalLessonColor
                    )

                    colorPicker(
                        "Leeres Feld",
                        value:
                            $emptyLessonColor
                    )

                    colorPicker(
                        "Freistunde",
                        value:
                            $freeLessonColor
                    )

                    colorPicker(
                        "Ausfall",
                        value:
                            $cancelledLessonColor
                    )

                    colorPicker(
                        "Vertretung",
                        value:
                            $substitutionLessonColor
                    )

                    colorPicker(
                        "Lehrer unbekannt",
                        value:
                            $unknownTeacherColor
                    )

                    colorPicker(
                        "Schulfrei",
                        value:
                            $schoolFreeColor
                    )
                }

                Section("Schulfreie Tage") {

                    DatePicker(
                        "Datum",
                        selection:
                            $newSchoolFreeDay,
                        displayedComponents:
                            .date
                    )

                    Button(
                        "Tag als schulfrei markieren"
                    ) {
                        addSchoolFreeDay()
                    }

                    if schoolFreeDayList.isEmpty {

                        Text(
                            "Noch keine Tage markiert."
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    } else {

                        ForEach(
                            schoolFreeDayList,
                            id: \.self
                        ) { day in

                            HStack {

                                Image(
                                    systemName:
                                        "sun.max.fill"
                                )
                                .foregroundStyle(
                                    Color(
                                        hex:
                                            schoolFreeColor
                                    )
                                )

                                Text(
                                    formattedSchoolFreeDay(
                                        day
                                    )
                                )

                                Spacer()

                                Button(
                                    role: .destructive
                                ) {
                                    removeSchoolFreeDay(
                                        day
                                    )
                                } label: {
                                    Image(
                                        systemName:
                                            "trash"
                                    )
                                }
                                .buttonStyle(
                                    .borderless
                                )
                            }
                        }
                    }
                }

    // MARK: - Destructive Buttons
                Section("Gelernter Stundenplan") {

                    Text(
                        "Die App merkt sich deinen Regelplan auf diesem Gerät und erkennt später fehlende Stunden als Ausfall."
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )

                    Button(
                        "Gelernten Stundenplan zurücksetzen",
                        role: .destructive
                    ) {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)

                        showResetLearnedConfirmation = true
                    }
                    .buttonStyle(PressableButtonStyle())
                    .foregroundStyle(.red)

                    .confirmationDialog(
                        "Gelernten Stundenplan zurücksetzen?",
                        isPresented: $showResetLearnedConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(
                            "Stundenplan zurücksetzen",
                            role: .destructive
                        ) {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)

                            resetLearnedSchedule()
                        }

                        Button("Abbrechen", role: .cancel) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    } message: {
                        Text(
                            "Die App vergisst alle bisher gelernten Regelstunden. Bereits geladene Daten bleiben erhalten."
                        )
                    }
                }

                Section("App Zurücksetzen") {

                    Text(
                        "Alle Daten der App löschen."
                    )
                    .font(.footnote)
                    .foregroundStyle(
                        .secondary
                    )

                    Button(
                        "App zurücksetzen",
                        role: .destructive
                    ) {
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)

                        showResetAppConfirmation = true
                    }
                    .buttonStyle(PressableButtonStyle())
                    .foregroundStyle(.red)

                    .confirmationDialog(
                        "App vollständig zurücksetzen?",
                        isPresented: $showResetAppConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(
                            "Alles löschen",
                            role: .destructive
                        ) {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)

                            resetAllAppData()
                        }

                        Button("Abbrechen", role: .cancel) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    } message: {
                        Text(
                            "Kalender-Link, Farben, schulfreie Tage und der gelernte Stundenplan werden gelöscht."
                        )
                    }
                }

            }
            .navigationTitle(
                "Einstellungen"
            )
            .toolbar {

                ToolbarItem(
                    placement:
                        .confirmationAction
                ) {

                    Button("Fertig") {
                        showingSettings =
                            false
                    }
                }
            }
        }
    }

    private func colorPicker(
        _ title: String,
        value: Binding<String>
    ) -> some View {

        ColorPicker(
            title,
            selection:
                Binding(
                    get: {
                        Color(
                            hex:
                                value.wrappedValue
                        )
                    },
                    set: {
                        value.wrappedValue =
                            $0.hexString
                    }
                ),
            supportsOpacity: false
        )
    }

    private func applyColorProfile(
        _ profile: String
    ) {

        switch profile {

        case "Nordlicht":

            backgroundStartColor = "#061C1B"
            backgroundEndColor = "#183A4A"
            normalLessonColor = "#145A5A"
            emptyLessonColor = "#0B2225"
            freeLessonColor = "#193638"
            cancelledLessonColor = "#B4233C"
            substitutionLessonColor = "#168C8C"
            unknownTeacherColor = "#B86B1C"
            schoolFreeColor = "#4B7A36"
            primaryTextColor = "#F1FFFB"
            secondaryTextColor = "#A5C8C3"
            todayColor = "#4DE2C5"
            tomorrowColor = "#8EC5FF"
            currentTimeColor = "#FF5C7A"
            pauseColor = "#75A7A1"

        case "Sonnenuntergang":

            backgroundStartColor = "#251126"
            backgroundEndColor = "#6A2C3B"
            normalLessonColor = "#5B2C4F"
            emptyLessonColor = "#211222"
            freeLessonColor = "#3B243A"
            cancelledLessonColor = "#D13F55"
            substitutionLessonColor = "#6B63D9"
            unknownTeacherColor = "#D98624"
            schoolFreeColor = "#A45E28"
            primaryTextColor = "#FFF6F7"
            secondaryTextColor = "#E7BFC7"
            todayColor = "#FF7C8D"
            tomorrowColor = "#CFA1FF"
            currentTimeColor = "#FFCF4D"
            pauseColor = "#D1A3AF"

        case "Neon":

            backgroundStartColor = "#07070D"
            backgroundEndColor = "#1A1035"
            normalLessonColor = "#151B4A"
            emptyLessonColor = "#0C0C15"
            freeLessonColor = "#202044"
            cancelledLessonColor = "#E6204B"
            substitutionLessonColor = "#00A9FF"
            unknownTeacherColor = "#FF8A00"
            schoolFreeColor = "#8C4DFF"
            primaryTextColor = "#F9F7FF"
            secondaryTextColor = "#B2AED0"
            todayColor = "#00E5FF"
            tomorrowColor = "#B75CFF"
            currentTimeColor = "#FF2DB2"
            pauseColor = "#7772A8"

        case "Ozean":

            backgroundStartColor = "#04151F"
            backgroundEndColor = "#075985"
            normalLessonColor = "#0C3B52"
            emptyLessonColor = "#061923"
            freeLessonColor = "#10445A"
            cancelledLessonColor = "#B91C3C"
            substitutionLessonColor = "#0891B2"
            unknownTeacherColor = "#C2410C"
            schoolFreeColor = "#176B87"
            primaryTextColor = "#F0FCFF"
            secondaryTextColor = "#8DBAC8"
            todayColor = "#22D3EE"
            tomorrowColor = "#60A5FA"
            currentTimeColor = "#FB7185"
            pauseColor = "#6695A5"

        case "Wald":

            backgroundStartColor = "#071A12"
            backgroundEndColor = "#163D2B"
            normalLessonColor = "#164A35"
            emptyLessonColor = "#0A2117"
            freeLessonColor = "#1B3B2D"
            cancelledLessonColor = "#B4233C"
            substitutionLessonColor = "#16835A"
            unknownTeacherColor = "#B86B1C"
            schoolFreeColor = "#3F7D3A"
            primaryTextColor = "#F2FFF7"
            secondaryTextColor = "#A6C8B4"
            todayColor = "#4ADE80"
            tomorrowColor = "#86EFAC"
            currentTimeColor = "#FB7185"
            pauseColor = "#78A88B"

        case "Lavendel":

            backgroundStartColor = "#171329"
            backgroundEndColor = "#3B2A60"
            normalLessonColor = "#332653"
            emptyLessonColor = "#141022"
            freeLessonColor = "#44366B"
            cancelledLessonColor = "#C0264D"
            substitutionLessonColor = "#7657D9"
            unknownTeacherColor = "#C27A2C"
            schoolFreeColor = "#7452B8"
            primaryTextColor = "#FAF7FF"
            secondaryTextColor = "#C2B6DD"
            todayColor = "#C084FC"
            tomorrowColor = "#A78BFA"
            currentTimeColor = "#FB5C9A"
            pauseColor = "#9F91BA"

        case "Eis":

            backgroundStartColor = "#08151E"
            backgroundEndColor = "#20445A"
            normalLessonColor = "#17445A"
            emptyLessonColor = "#0B1B25"
            freeLessonColor = "#24516A"
            cancelledLessonColor = "#C2415A"
            substitutionLessonColor = "#38A6C9"
            unknownTeacherColor = "#C47A35"
            schoolFreeColor = "#4F8499"
            primaryTextColor = "#F3FCFF"
            secondaryTextColor = "#B0CED9"
            todayColor = "#67E8F9"
            tomorrowColor = "#93C5FD"
            currentTimeColor = "#FF6B8A"
            pauseColor = "#86AEBB"

        case "Vulkan":

            backgroundStartColor = "#180706"
            backgroundEndColor = "#4A1710"
            normalLessonColor = "#552016"
            emptyLessonColor = "#1D0A08"
            freeLessonColor = "#68271B"
            cancelledLessonColor = "#E11D48"
            substitutionLessonColor = "#D94801"
            unknownTeacherColor = "#F59E0B"
            schoolFreeColor = "#9A4D20"
            primaryTextColor = "#FFF8F2"
            secondaryTextColor = "#E4B8A5"
            todayColor = "#FF7043"
            tomorrowColor = "#FDBA74"
            currentTimeColor = "#FFD166"
            pauseColor = "#B77D6B"

        case "Mitternacht":

            backgroundStartColor = "#020617"
            backgroundEndColor = "#111827"
            normalLessonColor = "#172554"
            emptyLessonColor = "#030712"
            freeLessonColor = "#1E293B"
            cancelledLessonColor = "#991B1B"
            substitutionLessonColor = "#1D4ED8"
            unknownTeacherColor = "#B45309"
            schoolFreeColor = "#475569"
            primaryTextColor = "#F8FAFC"
            secondaryTextColor = "#94A3B8"
            todayColor = "#38BDF8"
            tomorrowColor = "#818CF8"
            currentTimeColor = "#F43F5E"
            pauseColor = "#64748B"

        case "Rosé":

            backgroundStartColor = "#211017"
            backgroundEndColor = "#54263A"
            normalLessonColor = "#55283F"
            emptyLessonColor = "#1C0D14"
            freeLessonColor = "#68334E"
            cancelledLessonColor = "#D92955"
            substitutionLessonColor = "#A855F7"
            unknownTeacherColor = "#D97706"
            schoolFreeColor = "#9F4C68"
            primaryTextColor = "#FFF7FA"
            secondaryTextColor = "#DDB5C4"
            todayColor = "#FB7185"
            tomorrowColor = "#C084FC"
            currentTimeColor = "#FF4F81"
            pauseColor = "#B98296"

        case "Cyber":

            backgroundStartColor = "#05050B"
            backgroundEndColor = "#17102E"
            normalLessonColor = "#171A4A"
            emptyLessonColor = "#080811"
            freeLessonColor = "#202354"
            cancelledLessonColor = "#F43F5E"
            substitutionLessonColor = "#06B6D4"
            unknownTeacherColor = "#F97316"
            schoolFreeColor = "#8B5CF6"
            primaryTextColor = "#F8FAFF"
            secondaryTextColor = "#A5B4FC"
            todayColor = "#22D3EE"
            tomorrowColor = "#C084FC"
            currentTimeColor = "#FF2DA6"
            pauseColor = "#7777A8"

        case "Kupfer":

            backgroundStartColor = "#17100C"
            backgroundEndColor = "#4A2A1B"
            normalLessonColor = "#56301E"
            emptyLessonColor = "#1B110C"
            freeLessonColor = "#663B25"
            cancelledLessonColor = "#B4233C"
            substitutionLessonColor = "#B85C16"
            unknownTeacherColor = "#D88924"
            schoolFreeColor = "#85602D"
            primaryTextColor = "#FFF9F2"
            secondaryTextColor = "#D5B79D"
            todayColor = "#F59E0B"
            tomorrowColor = "#D6A77A"
            currentTimeColor = "#FF5F56"
            pauseColor = "#A98A73"

        case "Matrix":

            backgroundStartColor = "#020805"
            backgroundEndColor = "#0B2B16"
            normalLessonColor = "#0B3D1D"
            emptyLessonColor = "#020A05"
            freeLessonColor = "#124D25"
            cancelledLessonColor = "#9F1239"
            substitutionLessonColor = "#059669"
            unknownTeacherColor = "#84CC16"
            schoolFreeColor = "#166534"
            primaryTextColor = "#ECFDF5"
            secondaryTextColor = "#86EFAC"
            todayColor = "#22C55E"
            tomorrowColor = "#4ADE80"
            currentTimeColor = "#EF4444"
            pauseColor = "#4D9A68"

        default:

            backgroundStartColor = "#07111F"
            backgroundEndColor = "#172B4D"
            normalLessonColor = "#132033"
            emptyLessonColor = "#0C111B"
            freeLessonColor = "#182230"
            cancelledLessonColor = "#B4233C"
            substitutionLessonColor = "#0B6E8A"
            unknownTeacherColor = "#A15416"
            schoolFreeColor = "#6B4A0D"
            primaryTextColor = "#F6F8FF"
            secondaryTextColor = "#AAB7D1"
            todayColor = "#4EA5FF"
            tomorrowColor = "#A78BFA"
            currentTimeColor = "#FF4D6D"
            pauseColor = "#74829E"
        }
    }

    private var schoolFreeDayList: [String] {

        schoolFreeDays
            .split(separator: ",")
            .map(String.init)
            .sorted()
    }

    private func isSchoolFree(
        _ date: Date
    ) -> Bool {

        schoolFreeDayList.contains(
            schoolFreeDayKey(date)
        )
    }

    private func addSchoolFreeDay() {

        let day =
            schoolFreeDayKey(
                newSchoolFreeDay
            )

        guard
            !schoolFreeDayList.contains(day)
        else {
            return
        }

        schoolFreeDays =
            (
                schoolFreeDayList
                + [day]
            )
            .sorted()
            .joined(separator: ",")
    }

    private func removeSchoolFreeDay(
        _ day: String
    ) {

        schoolFreeDays =
            schoolFreeDayList
                .filter {
                    $0 != day
                }
                .joined(separator: ",")
    }

    private func schoolFreeDayKey(
        _ date: Date
    ) -> String {

        let formatter =
            DateFormatter()

        formatter.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        formatter.timeZone =
            TimeZone(
                identifier:
                    "Europe/Berlin"
            )

        formatter.dateFormat =
            "yyyy-MM-dd"

        return formatter.string(
            from: date
        )
    }

    private func formattedSchoolFreeDay(
        _ day: String
    ) -> String {

        let input =
            DateFormatter()

        input.locale =
            Locale(
                identifier:
                    "en_US_POSIX"
            )

        input.timeZone =
            TimeZone(
                identifier:
                    "Europe/Berlin"
            )

        input.dateFormat =
            "yyyy-MM-dd"

        guard
            let date =
                input.date(
                    from: day
                )
        else {
            return day
        }

        let output =
            DateFormatter()

        output.locale =
            Locale(
                identifier:
                    "de_DE"
            )

        output.dateFormat =
            "EEEE, d. MMMM yyyy"

        return output.string(
            from: date
        )
    }

    private var schoolFreeBanner: some View {

        Label(
            "Schulfrei",
            systemImage:
                "sun.max.fill"
        )
        .font(
            .system(
                size: 15,
                weight: .bold
            )
        )
        .foregroundStyle(.white)
        .frame(
            maxWidth: .infinity
        )
        .padding(
            .vertical,
            9
        )
        .background(
            RoundedRectangle(
                cornerRadius: 12
            )
            .fill(
                Color(
                    hex:
                        schoolFreeColor
                )
            )
        )
        .padding(
            .horizontal,
            30
        )
    }

    // MARK: - Reload

    private func reload() async {

        guard !reloading else {
            return
        }

        reloading = true
        errorMessage = nil

        do {

            let newEvents =
                try await loadEduPage(
                    urlString:
                        calendarURL
                )

            events =
                newEvents

            loading = false
            reloading = false

        } catch {

            errorMessage =
                error.localizedDescription

            loading = false
            reloading = false
        }
    }

    // MARK: - Loading

    private var loadingView: some View {

        ZStack {

            Color.black
                .opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 12) {

                ProgressView()
                    .tint(.white)

                Text(
                    "Stundenplan wird geladen…"
                )
                .foregroundStyle(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(
                    cornerRadius: 18
                )
                .fill(
                    .black.opacity(0.78)
                )
            )
        }
    }

    // MARK: - Fehler

    private func errorView(
        _ message: String
    ) -> some View {

        VStack(spacing: 8) {

            Text(
                "Fehler beim Laden"
            )
            .font(
                .system(
                    size: 18,
                    weight: .bold
                )
            )

            Text(message)
                .font(
                    .system(size: 13)
                )
                .multilineTextAlignment(
                    .center
                )

            Button(
                "Einstellungen öffnen"
            ) {
                errorMessage = nil
                showingSettings = true
            }
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .buttonStyle(
                .borderedProminent
            )
            .tint(
                .white.opacity(0.18)
            )
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(
            RoundedRectangle(
                cornerRadius: 16
            )
            .fill(
                .red.opacity(0.8)
            )
        )
        .padding(30)
    }
}

private extension Color {

    init(hex: String) {

        let value =
            hex
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .replacingOccurrences(
                    of: "#",
                    with: ""
                )

        guard
            value.count == 6,
            let number =
                UInt64(
                    value,
                    radix: 16
                )
        else {

            self =
                Color(
                    red: 0.075,
                    green: 0.12,
                    blue: 0.19
                )

            return
        }

        self.init(
            red:
                Double(
                    (number >> 16)
                    & 0xFF
                ) / 255,

            green:
                Double(
                    (number >> 8)
                    & 0xFF
                ) / 255,

            blue:
                Double(
                    number & 0xFF
                ) / 255
        )
    }

    var hexString: String {

        let color =
            UIColor(self)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard
            color.getRed(
                &red,
                green: &green,
                blue: &blue,
                alpha: &alpha
            )
        else {
            return "#132033"
        }

        return String(
            format:
                "#%02lX%02lX%02lX",

            lroundf(
                Float(red * 255)
            ),

            lroundf(
                Float(green * 255)
            ),

            lroundf(
                Float(blue * 255)
            )
        )
    }
}