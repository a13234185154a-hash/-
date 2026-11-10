import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 可配置小组件：长按小组件 → 编辑 → 选择要显示的事件

struct EventEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "事件")
    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: DisplayRepresentation.NamedString(name))
    }
}

struct EventQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async -> [EventEntity] {
        Store.loadEvents().filter { identifiers.contains($0.id) }
            .map { EventEntity(id: $0.id, name: $0.name) }
    }

    func suggestions() async -> [EventEntity] {
        Store.sortedEvents().map { EventEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> EventEntity? {
        Store.sortedEvents().first.map { EventEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectEventIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "选择事件"
    static let description = IntentDescription("选择要在这个小组件上显示的天数事件")

    @Parameter(title: "事件")
    var event: EventEntity?
}

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let event: Event?          // 配置选中（或置顶）的事件
    let nextCountdown: Event?  // 中号组件的"下一个倒数日"
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), event: demo, nextCountdown: nil)
    }

    func snapshot(for configuration: SelectEventIntent, in context: Context) async -> Entry {
        entry(for: configuration, in: context)
    }

    func timeline(for configuration: SelectEventIntent, in context: Context) async -> Timeline<Entry> {
        let e = entry(for: configuration, in: context)
        // 每天零点后刷新天数
        let next = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
        return Timeline(entries: [e], policy: .after(next))
    }

    private var demo: Event {
        var ev = Event(); ev.name = "在一起"; ev.date = "2023-03-24"; ev.colorIndex = 0
        return ev
    }

    private func entry(for configuration: SelectEventIntent, in context: Context) -> Entry {
        let all = Store.sortedEvents()
        let ev: Event?
        if let id = configuration.event?.id, let match = all.first(where: { $0.id == id }) {
            ev = match
        } else {
            ev = all.first { $0.pinned } ?? all.first
        }
        var next: Event? = nil
        if context.family == .systemMedium {
            next = all.filter { $0.id != ev?.id && $0.type == .down && DayMath.countdown($0) != nil }
                .min { (DayMath.countdown($0) ?? 0) < (DayMath.countdown($1) ?? 0) }
        }
        return Entry(date: Date(), event: ev, nextCountdown: next)
    }
}

// MARK: - 视图

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
            .foregroundColor(light ? .white : pal.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(pal.bg)
    }
}

struct DaysWidgetView: View {
    var entry: Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            if let ev = entry.event {
                WidgetCardView(event: ev, compact: true).widgetBackground()
            } else {
                emptyView.widgetBackground()
            }
        case .systemMedium:
            HStack(spacing: 0) {
                if let ev = entry.event {
                    WidgetCardView(event: ev)
                        .frame(maxWidth: .infinity)
                }
                if let next = entry.nextCountdown, let n = DayMath.countdown(next) {
                    Divider().frame(height: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("下一个")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Text(next.name)
                            .font(.system(size: 13))
                        Text(n == 0 ? "今天" : "\(n) 天后")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                }
            }
            .widgetBackground()
        case .accessoryInline:
            if let ev = entry.event, let d = Optional(ev.display()) {
                Text("\(ev.name) \(d.big)\(d.unit)")
            }
        case .accessoryCircular:
            if let ev = entry.event, let n = (ev.type == .up ? DayMath.daysSince(ev.date) : DayMath.countdown(ev)) {
                Gauge(value: Double(n % 1000), in: 0...1000) {
                    Text(ev.name.prefix(2))
                } currentValueLabel: {
                    Text("\(n)")
                        .font(.system(size: 16, weight: .medium))
                }
                .gaugeStyle(.accessoryCircular)
            } else {
                Text("Days")
            }
        default:
            if let ev = entry.event {
                WidgetCardView(event: ev).widgetBackground()
            } else {
                emptyView.widgetBackground()
            }
        }
    }

    var emptyView: some View {
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
