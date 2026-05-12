import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    let baby: Baby?

    @State private var queryType: InsightsQueryType = .medications
    @State private var keyword: String = ""
    @State private var period: InsightsPeriod = .lastMonth

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    filterSection
                    Divider()
                    if baby == nil {
                        ContentUnavailableView(
                            "No baby selected",
                            systemImage: "person.crop.circle",
                            description: Text("Select a baby from the Profiles tab.")
                        )
                        .padding(.top, 40)
                    } else {
                        switch queryType {
                        case .medications: medicationResultsSection
                        case .illnesses:   illnessResultsSection
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Filter section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Query type", selection: $queryType) {
                ForEach(InsightsQueryType.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)

            TextField("Filter by name…", text: $keyword)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            HStack {
                Text("Period")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                Picker("Period", selection: $period) {
                    ForEach(InsightsPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Data projection

    private var allMedicationEvents: [MedicationEvent] {
        guard let baby else { return [] }
        var events: [MedicationEvent] = []
        for plan in baby.plans {
            for record in plan.records {
                events.append(MedicationEvent(
                    id: record.id,
                    date: record.recordedDate,
                    status: record.status == .taken ? .taken : .skipped,
                    medicationName: plan.medicationName,
                    doseSummary: plan.doseSummary
                ))
            }
        }
        for quick in baby.quickDoses {
            events.append(MedicationEvent(
                id: quick.id,
                date: quick.givenAt,
                status: .quick,
                medicationName: quick.medicationName,
                doseSummary: quick.doseSummary
            ))
        }
        return events
    }

    private var allIllnessSnapshots: [IllnessSnapshot] {
        (baby?.illnesses ?? []).map { illness in
            IllnessSnapshot(
                id: illness.id,
                title: illness.title,
                startDate: illness.startDate,
                endDate: illness.endDate,
                durationSummary: illness.durationSummary,
                isOngoing: illness.isOngoing
            )
        }
    }

    // MARK: - Results

    private var currentDateRange: ClosedRange<Date> { InsightsEngine.dateRange(for: period) }

    private var medicationResult: MedicationInsightResult {
        InsightsEngine.medicationInsights(events: allMedicationEvents, keyword: keyword, range: currentDateRange)
    }

    private var illnessResult: IllnessInsightResult {
        InsightsEngine.illnessInsights(illnesses: allIllnessSnapshots, keyword: keyword, range: currentDateRange)
    }

    // MARK: - Medication results

    @ViewBuilder
    private var medicationResultsSection: some View {
        let result = medicationResult
        if result.events.isEmpty {
            ContentUnavailableView(
                "No results",
                systemImage: "pills",
                description: Text(keyword.isEmpty
                    ? "No doses recorded for this period."
                    : "No doses matching \"\(keyword)\".")
            )
            .padding(.top, 24)
        } else {
            HStack(spacing: 12) {
                InsightStatCard(value: "\(result.takenCount)",     label: "Taken",   color: .green)
                InsightStatCard(value: "\(result.skippedCount)",   label: "Skipped", color: .secondary)
                InsightStatCard(value: "\(result.quickDoseCount)", label: "Quick",   color: .blue)
            }

            recordList {
                ForEach(result.events) { event in
                    MedicationEventRow(event: event)
                    if event.id != result.events.last?.id { Divider().padding(.leading, 44) }
                }
            }

            medicationChart(result: result)
        }
    }

    // MARK: - Illness results

    @ViewBuilder
    private var illnessResultsSection: some View {
        let result = illnessResult
        if result.illnesses.isEmpty {
            ContentUnavailableView(
                "No results",
                systemImage: "stethoscope",
                description: Text(keyword.isEmpty
                    ? "No illnesses recorded for this period."
                    : "No illnesses matching \"\(keyword)\".")
            )
            .padding(.top, 24)
        } else {
            HStack(spacing: 12) {
                InsightStatCard(value: "\(result.totalCount)",                     label: "Total",    color: .orange)
                InsightStatCard(value: "\(result.longIllnessCount)",               label: ">3 days",  color: .red)
                InsightStatCard(
                    value: result.averageDurationDays == 0
                        ? "—"
                        : String(format: "%.1f", result.averageDurationDays),
                    label: "Avg days",
                    color: .purple
                )
            }

            IllnessCalendarView(illnesses: result.illnesses)

            recordList {
                ForEach(result.illnesses) { illness in
                    IllnessSnapshotRow(illness: illness)
                    if illness.id != result.illnesses.last?.id { Divider().padding(.leading, 16) }
                }
            }

            illnessChart(result: result)
        }
    }

    // MARK: - Shared list container

    private func recordList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Charts

    private func medicationChart(result: MedicationInsightResult) -> some View {
        let data = medicationBuckets(for: result)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Doses over time")
                .font(.headline)
                .padding(.top, 8)
            Chart {
                ForEach(data) { bucket in
                    BarMark(x: .value("Period", bucket.date, unit: xUnit), y: .value("Taken",   bucket.takenCount))
                        .foregroundStyle(by: .value("Status", "Taken"))
                    BarMark(x: .value("Period", bucket.date, unit: xUnit), y: .value("Skipped", bucket.skippedCount))
                        .foregroundStyle(by: .value("Status", "Skipped"))
                    BarMark(x: .value("Period", bucket.date, unit: xUnit), y: .value("Quick",   bucket.quickCount))
                        .foregroundStyle(by: .value("Status", "Quick"))
                }
            }
            .chartForegroundStyleScale([
                "Taken":   Color.green,
                "Skipped": Color.secondary.opacity(0.6),
                "Quick":   Color.blue.opacity(0.8)
            ])
            .chartXAxis { AxisMarks(values: .stride(by: xStride, count: xStrideCount)) }
            .frame(height: 180)
        }
    }

    private func illnessChart(result: IllnessInsightResult) -> some View {
        let data = illnessBuckets(for: result)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Illnesses by month")
                .font(.headline)
                .padding(.top, 8)
            Chart {
                ForEach(data) { bucket in
                    BarMark(x: .value("Month", bucket.date, unit: .month), y: .value("Count", bucket.count))
                        .foregroundStyle(Color.orange)
                }
            }
            .chartXAxis { AxisMarks(values: .stride(by: .month, count: 1)) }
            .frame(height: 160)
        }
    }

    // MARK: - Chart axis helpers

    private var xUnit: Calendar.Component {
        switch period {
        case .last7Days:              return .day
        case .lastMonth, .last3Months: return .weekOfYear
        case .lastYear, .allTime:     return .month
        }
    }

    private var xStride: Calendar.Component {
        switch period {
        case .last7Days:   return .day
        case .lastMonth:   return .weekOfYear
        case .last3Months: return .weekOfYear
        case .lastYear:    return .month
        case .allTime:     return .month
        }
    }

    private var xStrideCount: Int {
        switch period {
        case .last7Days, .lastMonth: return 1
        case .last3Months:           return 2
        case .lastYear, .allTime:    return 1
        }
    }

    // MARK: - Bucketing helpers

    private struct DoseBucket: Identifiable {
        let id = UUID()
        let date: Date
        let takenCount: Int
        let skippedCount: Int
        let quickCount: Int
    }

    private struct IllnessBucket: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    private func medicationBuckets(for result: MedicationInsightResult) -> [DoseBucket] {
        guard !result.events.isEmpty else { return [] }
        let cal = Calendar.current
        let unit = xUnit
        var groups: [Date: (taken: Int, skipped: Int, quick: Int)] = [:]
        for event in result.events {
            let key: Date
            switch unit {
            case .day:
                key = cal.startOfDay(for: event.date)
            case .weekOfYear:
                key = cal.dateInterval(of: .weekOfYear, for: event.date)!.start
            default:
                key = cal.dateInterval(of: .month, for: event.date)!.start
            }
            var existing = groups[key] ?? (0, 0, 0)
            switch event.status {
            case .taken:   existing.taken   += 1
            case .skipped: existing.skipped += 1
            case .quick:   existing.quick   += 1
            }
            groups[key] = existing
        }
        return groups.sorted { $0.key < $1.key }.map { key, val in
            DoseBucket(date: key, takenCount: val.taken, skippedCount: val.skipped, quickCount: val.quick)
        }
    }

    private func illnessBuckets(for result: IllnessInsightResult) -> [IllnessBucket] {
        guard !result.illnesses.isEmpty else { return [] }
        let cal = Calendar.current
        var groups: [Date: Int] = [:]
        for illness in result.illnesses {
            let key = cal.dateInterval(of: .month, for: illness.startDate)!.start
            groups[key, default: 0] += 1
        }
        return groups.sorted { $0.key < $1.key }.map { IllnessBucket(date: $0.key, count: $0.value) }
    }
}

// MARK: - Sub-views

private struct InsightStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MedicationEventRow: View {
    let event: MedicationEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.medicationName)
                    .font(.subheadline.weight(.medium))
                Text(event.doseSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(event.date, format: .dateTime.day().month().hour().minute())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var iconName: String {
        switch event.status {
        case .taken:   return "checkmark.circle.fill"
        case .skipped: return "forward.circle.fill"
        case .quick:   return "pills.fill"
        }
    }

    private var iconColor: Color {
        switch event.status {
        case .taken:   return .green
        case .skipped: return .secondary
        case .quick:   return .blue
        }
    }
}

private struct IllnessSnapshotRow: View {
    let illness: IllnessSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(illness.title)
                    .font(.subheadline.weight(.medium))
                Text(illness.durationSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(illness.isOngoing ? "Ongoing" : "Recovered")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(illness.isOngoing ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                .foregroundStyle(illness.isOngoing ? .orange : .green)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Illness calendar

private struct IllnessCalendarView: View {
    let illnesses: [IllnessSnapshot]

    private let cal = Calendar.current
    @State private var displayedMonth: Date = {
        let comps = Calendar.current.dateComponents([.year, .month], from: .now)
        return Calendar.current.date(from: comps)!
    }()

    private var illnessDayIDs: Set<Int> { InsightsEngine.illnessDayIDs(for: illnesses) }
    private var startDayIDs: Set<Int>   { InsightsEngine.illnessStartDayIDs(for: illnesses) }

    private var gridDays: [Date?] {
        guard let firstDay = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
              let daysInMonth = cal.range(of: .day, in: .month, for: firstDay)
        else { return [] }
        let firstWeekday = cal.component(.weekday, from: firstDay)
        let offset = (firstWeekday - cal.firstWeekday + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        for i in 0..<daysInMonth.count {
            days.append(cal.date(byAdding: .day, value: i, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var weekdayHeaders: [String] {
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calendar")
                .font(.headline)
                .padding(.top, 4)

            VStack(spacing: 8) {
                HStack {
                    Button { navigate(-1) } label: {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                    Spacer()
                    Text(displayedMonth, format: .dateTime.month(.wide).year())
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { navigate(1) } label: {
                        Image(systemName: "chevron.right").fontWeight(.semibold)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                    ForEach(weekdayHeaders, id: \.self) { header in
                        Text(header)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            let id = InsightsEngine.dayID(for: day)
                            IllnessDayCell(
                                day: day,
                                hasIllness: illnessDayIDs.contains(id),
                                isStart: startDayIDs.contains(id)
                            )
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }

                HStack(spacing: 16) {
                    Label("Illness day", systemImage: "circle.fill")
                        .foregroundStyle(.orange.opacity(0.7))
                    Label("Start", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                    Label("Today", systemImage: "circle")
                        .foregroundStyle(.blue)
                }
                .font(.caption2)
                .padding(.top, 2)
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func navigate(_ offset: Int) {
        if let m = cal.date(byAdding: .month, value: offset, to: displayedMonth) {
            displayedMonth = m
        }
    }
}

private struct IllnessDayCell: View {
    let day: Date
    let hasIllness: Bool
    let isStart: Bool

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        ZStack {
            if hasIllness {
                Circle().fill(Color.orange.opacity(0.2))
            }
            if isToday {
                Circle().strokeBorder(Color.blue, lineWidth: 1.5)
            }
            VStack(spacing: 0) {
                Text(day, format: .dateTime.day())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(hasIllness ? .orange : (isToday ? .blue : .primary))
                Circle()
                    .fill(isStart ? Color.orange : .clear)
                    .frame(width: 4, height: 4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    InsightsView(baby: nil)
        .modelContainer(previewContainer)
}
