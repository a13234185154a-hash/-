import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 可配置项（长按小组件 → 编辑小组件 → 选择事件）

struct EventEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "事件")
    static let defaultQuery = EventQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct EventQuery: EntityQuery {
    func entities(for identifiers: [EventEntity.ID]) async throws -> [EventEntity] {
        Store.loadEvents()
            .filter { identifiers.contains($0.id) }
            .map { EventEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [EventEntity] {
        Store.sortedEvents().map { EventEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> EventEntity? {
        Store.sortedEvents().first.map { EventEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectEventIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择显示的事件"
    static let description = IntentDescription("选择这个小组件要显示的天数事件")

    @Parameter(title: "事件")
    var event: EventEntity?
}

// MARK: - Timeline

struct DaysEntry: TimelineEntry {
    let date: Date
    let event: Event?          // 配置选中的（或置顶的）事件
    let nextCountdown: Event?  // 中号组件的「下一个倒数日」
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), event: demo, nextCountdown: nil)
    }

    func snapshot(for configuration: SelectEventIntent, in context: Context) async -> DaysEntry {
        makeEntry(for: configuration, in: context)
    }

    func timeline(for configuration: SelectEventIntent, in context: Context) async -> Timeline<DaysEntry> {
        let entry = makeEntry(for: configuration, in: context)
        // 每天零点后自动刷新天数
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        return Timeline(entries: [entry], policy: .after(tomorrow))
    }

    private var demo: Event {
        var ev = Event()
        ev.name = "在一起"
        ev.date = "2023-03-24"
        ev.colorIndex = 0
        return ev
    }

    private func makeEntry(for configuration: SelectEventIntent, in context: Context) -> DaysEntry {
        let all = Store.sortedEvents()
        var selected: Event?
        if let id = configuration.event?.id {
            selected = all.first { $0.id == id }
        }
        if selected == nil {
            selected = all.first { $0.pinned } ?? all.first
        }

        var next: Event?
        if context.family == .systemMedium {
            next = all
                .filter { $0.id != selected?.id && $0.type == .down && DayMath.countdown($0) != nil }
                .min { (DayMath.countdown($0) ?? 0) < (DayMath.countdown($1) ?? 0) }
        }
        return DaysEntry(date: Date(), event: selected, nextCountdown: next)
    }
}

// MARK: - 卡片视图

struct WidgetCardView: View {
    let event: Event
    var compact: Bool = false

    var body: some View {
        let pal = palettes[event.colorIndex % palettes.count]
        let d = event.display()
        let image = Store.loadImage(event.imageFile)
        let opacity = Double(event.imgOpacity ?? 100) / 100
        let scrim = max(0, opacity - 0.5) * 0.9
        let light = image != nil && opacity >= 0.5

        ZStack {
            if let image {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(opacity)
                    Color.black.opacity(scrim)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.system(size: compact ? 11 : 12))
                    .opacity(0.8)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(d.big)
                        .font(.system(size: compact ? 26 : 30, weight: .medium))
                    if !d.unit.isEmpty {
                        Text(d.unit)
                            .font(.system(size: 12))
                    }
                }
                if !compact {
                    Text(d.sub)
                        .font(.system(size: 10.5))
                        .opacity(0.65)
                }
            }
            .foregroundColor(light ? Color.white : pal.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(compact ? 2 : 4)
        }
        .background(pal.bg)
    }
}

// MARK: - 组件主体

struct DaysWidgetView: View {
    var entry: DaysEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryInline:
                inlineView
            case .accessoryCircular:
                circularView
            default:
                smallView
            }
        }
        .widgetBackground()
    }

    @ViewBuilder
    private var smallView: some View {
        if let ev = entry.event {
            WidgetCardView(event: ev, compact: true)
        } else {
            emptyView
        }
    }

    @ViewBuilder
    private var mediumView: some View {
        HStack(spacing: 0) {
            if let ev = entry.event {
                WidgetCardView(event: ev)
                    .frame(maxWidth: .infinity)
            }
            if let next = entry.nextCountdown, let n = DayMath.countdown(next) {
                Divider().frame(height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("下一个")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(next.name)
                        .font(.system(size: 13))
                    Text(n == 0 ? "今天" : "\(n) 天后")
                        .font(.system(size: 15, weight: .medium))
                }
                .padding(.horizontal, 14)
            }
        }
    }

    @ViewBuilder
    private var inlineView: some View {
        if let ev = entry.event {
            let d = ev.display()
            Text("\(ev.name) \(d.big)\(d.unit)")
        } else {
            Text("暂无事件")
        }
    }

    @ViewBuilder
    private var circularView: some View {
        if let ev = entry.event {
            let n = (ev.type == .up ? DayMath.daysSince(ev.date) : DayMath.countdown(ev)) ?? 0
            Gauge(value: Double(n % 1000), in: 0...1000) {
                Text(ev.name)
            } currentValueLabel: {
                Text("\(n)")
                    .font(.system(size: 16, weight: .medium))
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            Text("Days")
        }
    }

    private var emptyView: some View {
        Text("暂无事件")
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

extension View {
    func widgetBackground() -> some View {
        containerBackground(for: .widget) { Color(hex: 0xFFFDF8) }
    }
}

// MARK: - 注册

struct DaysWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DaysWidget",
                               intent: SelectEventIntent.self,
                               provider: Provider()) { entry in
            DaysWidgetView(entry: entry)
        }
        .configurationDisplayName("Days 天数")
        .description("显示累计天数与倒数日，长按可切换事件")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular])
    }
}

@main
struct DaysWidgetBundle: WidgetBundle {
    var body: some Widget {
        DaysWidget()
    }
}
