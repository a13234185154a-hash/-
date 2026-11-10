import Foundation

// MARK: - 数据模型（App 与小组件共用）

enum EventType: String, Codable {
    case up    // 累计天数（正计时）
    case down  // 倒数日（倒计时）
}

struct Event: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String = ""
    var date: String = ""          // yyyy-MM-dd
    var type: EventType = .up
    var repeatYearly: Bool = false // 每年重复（生日/纪念日）
    var colorIndex: Int = 0
    var pinned: Bool = false       // 置顶（App 内大卡片展示）
    var order: Int = 0
    var imageFile: String? = nil   // App Group 容器内的图片文件名
    var imgOpacity: Int? = nil     // 图片背景透明度 10–100，默认 100
}

// MARK: - 调色板

import SwiftUI

struct Palette {
    let bg: Color
    let ink: Color
}

let palettes: [Palette] = [
    .init(bg: Color(hex: 0xFBEAF0), ink: Color(hex: 0x4B1528)),
    .init(bg: Color(hex: 0xEEEDFE), ink: Color(hex: 0x26215C)),
    .init(bg: Color(hex: 0xE1F5EE), ink: Color(hex: 0x04342C)),
    .init(bg: Color(hex: 0xFAEEDA), ink: Color(hex: 0x412402)),
    .init(bg: Color(hex: 0xE6F1FB), ink: Color(hex: 0x042C53)),
    .init(bg: Color(hex: 0xF1EFE8), ink: Color(hex: 0x2C2C2A)),
    .init(bg: Color(hex: 0xFCEBEB), ink: Color(hex: 0x501313)),
    .init(bg: Color(hex: 0xEAF3DE), ink: Color(hex: 0x173404)),
]

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - 天数计算

struct DayMath {
    static let day: TimeInterval = 86400

    static func parse(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.date(from: s)
    }

    static func startOfDay(_ d: Date) -> Date {
        Calendar.current.startOfDay(for: d)
    }

    /// 累计天数：起始日当天算第 1 天
    static func daysSince(_ dateStr: String) -> Int? {
        guard let d = parse(dateStr) else { return nil }
        return Int((startOfDay(Date()).timeIntervalSince(startOfDay(d)) / day).rounded(.up)) + 1
    }

    /// 倒计时：每年重复自动取下一次；已过期返回 nil
    static func countdown(_ ev: Event) -> Int? {
        guard let target = parse(ev.date) else { return nil }
        let today = startOfDay(Date())
        let cal = Calendar.current
        if ev.repeatYearly {
            var candidate = cal.date(from: DateComponents(year: cal.component(.year, from: today),
                                                          month: cal.component(.month, from: target),
                                                          day: cal.component(.day, from: target)))!
            if candidate < today {
                candidate = cal.date(byAdding: .year, value: 1, to: candidate)!
            }
            return Int(candidate.timeIntervalSince(today) / day)
        }
        let diff = Int(target.timeIntervalSince(today) / day)
        return diff >= 0 ? diff : nil
    }
}

// MARK: - 展示结果

struct Display {
    let big: String      // 大数字（或"今天"等）
    let unit: String     // 单位
    let sub: String      // 副标题
    let expired: Bool
}

extension Event {
    func display() -> Display {
        let sub = "始于 " + date.replacingOccurrences(of: "-", with: ".")
        switch type {
        case .up:
            let n = DayMath.daysSince(date) ?? 0
            return Display(big: "\(n)", unit: "天", sub: sub, expired: false)
        case .down:
            guard let n = DayMath.countdown(self) else {
                return Display(big: "已过期", unit: "", sub: date.replacingOccurrences(of: "-", with: "."), expired: true)
            }
            if n == 0 {
                return Display(big: "就是", unit: "今天", sub: sub, expired: false)
            }
            return Display(big: "\(n)", unit: "天后", sub: sub, expired: false)
        }
    }
}

// MARK: - 数据存取（App Group 共享，小组件可读）

import WidgetKit

let appGroupID = "group.com.daysapp.shared"

enum Store {
    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func loadEvents() -> [Event] {
        guard let data = defaults?.data(forKey: "events"),
              let list = try? JSONDecoder().decode([Event].self, from: data) else { return [] }
        return list
    }

    static func saveEvents(_ list: [Event], reloadWidgets: Bool = false) {
        if let data = try? JSONEncoder().encode(list) {
            defaults?.set(data, forKey: "events")
        }
        if reloadWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func imageURL(_ name: String) -> URL {
        containerURL.appendingPathComponent(name)
    }

    static func saveImage(_ data: Data) -> String {
        let name = "img_\(UUID().uuidString).jpg"
        try? data.write(to: imageURL(name))
        return name
    }

    static func loadImage(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let d = try? Data(contentsOf: imageURL(name)) { return UIImage(data: d) }
        return nil
    }

    static func deleteImage(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: imageURL(name))
    }

    static func sortedEvents() -> [Event] {
        loadEvents().sorted { ($0.pinned ? 0 : 1, $0.order) < ($1.pinned ? 0 : 1, $1.order) }
    }

    // MARK: 页面背景（自定义图片 + 透明度）

    static func loadBackgroundImage() -> UIImage? {
        loadImage(defaults?.string(forKey: "pagebg"))
    }

    static func saveBackgroundImage(_ data: Data?) {
        if let old = defaults?.string(forKey: "pagebg") { deleteImage(old) }
        if let data {
            let name = saveImage(data)
            defaults?.set(name, forKey: "pagebg")
        } else {
            defaults?.removeObject(forKey: "pagebg")
        }
    }

    /// 页面背景透明度 5–100，默认 40
    static var backgroundOpacity: Int {
        get {
            let v = defaults?.integer(forKey: "pagebg_op") ?? 0
            return v == 0 ? 40 : v
        }
        set { defaults?.set(newValue, forKey: "pagebg_op") }
    }
}
