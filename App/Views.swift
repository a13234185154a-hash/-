import SwiftUI
import PhotosUI

// MARK: - 首页

struct ContentView: View {
    @State private var events: [Event] = Store.sortedEvents()
    @State private var editing: Event? = nil
    @State private var showEditor = false
    @State private var showBackground = false
    @State private var bgImage: UIImage? = Store.loadBackgroundImage()
    @State private var bgOpacity: Double = Double(Store.backgroundOpacity)

    var sorted: [Event] { events.sorted { ($0.pinned ? 0 : 1, $0.order) < ($1.pinned ? 0 : 1, $1.order) } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: 0xFFFDF8).ignoresSafeArea()
            if let bgImage {
                GeometryReader { geo in
                    Image(uiImage: bgImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(bgOpacity / 100)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            ScrollView {
                VStack(spacing: 0) {
                    dateHeader
                    chips
                    if sorted.isEmpty {
                        emptyHint
                    } else {
                        let pinned = sorted.first { $0.pinned }
                        let rest = sorted.filter { $0.id != pinned?.id }
                        if let p = pinned {
                            EventCard(event: p, isPinned: true)
                                .padding(.bottom, 14)
                                .onTapGesture { editing = p; showEditor = true }
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                            ForEach(rest) { ev in
                                EventCard(event: ev, isPinned: false)
                                    .onTapGesture { editing = ev; showEditor = true }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
            }
            addButton
        }
        .sheet(isPresented: $showEditor, onDismiss: reload) {
            EventEditor(event: editing)
        }
        .sheet(isPresented: $showBackground, onDismiss: reloadBg) {
            BackgroundPicker()
        }
    }

    var dateHeader: some View {
        let d = Date()
        let week = ["日", "一", "二", "三", "四", "五", "六"][Calendar.current.component(.weekday, from: d) - 1]
        return VStack(spacing: 4) {
            Text("\(Calendar.current.component(.month, from: d))月\(Calendar.current.component(.day, from: d))日")
                .font(.system(size: 26, weight: .medium))
            Text("星期\(week) · \(Calendar.current.component(.year, from: d))")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    var chips: some View {
        HStack(spacing: 8) {
            Text("背景")
                .font(.system(size: 12))
                .foregroundColor(bgImage == nil ? .gray : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(bgImage == nil ? Color.white : Color(hex: 0x3A3630)))
                .overlay(Capsule().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                .onTapGesture { showBackground = true }
        }
        .padding(.bottom, 16)
    }

    var emptyHint: some View {
        VStack(spacing: 8) {
            Text("还没有事件")
            Text("点右下角 ＋ 添加第一个")
        }
        .font(.system(size: 13))
        .foregroundColor(.gray)
        .padding(.vertical, 120)
    }

    var addButton: some View {
        Button {
            editing = nil
            showEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color(hex: 0xD85A30)))
                .shadow(color: Color(hex: 0xD85A30).opacity(0.35), radius: 10, y: 5)
        }
        .padding(.trailing, 22)
        .padding(.bottom, 30)
    }

    func reload() {
        events = Store.sortedEvents()
    }

    func reloadBg() {
        bgImage = Store.loadBackgroundImage()
        bgOpacity = Double(Store.backgroundOpacity)
        events = Store.sortedEvents()
    }
}

// MARK: - 事件卡片（图片背景 + 透明度）

struct EventCard: View {
    let event: Event
    let isPinned: Bool

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
            VStack(alignment: .leading, spacing: 6) {
                Text(event.name + (event.repeatYearly ? " · 每年" : ""))
                    .font(.system(size: 13))
                    .opacity(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(d.big)
                        .font(.system(size: isPinned ? 58 : 30, weight: .medium))
                    if !d.unit.isEmpty {
                        Text(d.unit).font(.system(size: 15))
                    }
                }
                Text(d.sub)
                    .font(.system(size: 11.5))
                    .opacity(0.7)
            }
            .foregroundColor(light ? .white : pal.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isPinned ? 26 : 18)
            .shadow(color: light ? .black.opacity(0.35) : .clear, radius: 3, y: 1)
        }
        .frame(maxWidth: .infinity, minHeight: isPinned ? 132 : 108, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(pal.bg))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
    }
}

// MARK: - 添加 / 编辑

struct EventEditor: View {
    var event: Event?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var date = Date()
    @State private var type: EventType = .up
    @State private var repeatYearly = false
    @State private var colorIndex = 0
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var hadImage = false
    @State private var imgOpacity: Double = 100

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("例如：在一起 / 生日 / 考试", text: $name)
                }
                Section("类型") {
                    Picker("类型", selection: $type) {
                        Text("累计天数").tag(EventType.up)
                        Text("倒数日").tag(EventType.down)
                    }
                    .pickerStyle(.segmented)
                    Toggle("每年重复（生日、纪念日）", isOn: $repeatYearly)
                }
                Section(type == .up ? "开始日期" : "目标日期") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }
                Section("背景颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(palettes.indices, id: \.self) { i in
                            Circle()
                                .fill(palettes[i].bg)
                                .frame(width: 34, height: 34)
                                .overlay(Circle().strokeBorder(colorIndex == i ? Color.primary : Color.black.opacity(0.1), lineWidth: colorIndex == i ? 2 : 0.5))
                                .onTapGesture { colorIndex = i }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("图片背景") {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        if pickedImage != nil {
                            Label("已选择图片（保存后生效）", systemImage: "checkmark.circle.fill")
                        } else if hadImage {
                            Label("保留原图片", systemImage: "photo")
                        } else {
                            Label("从相册选择图片", systemImage: "plus.circle")
                        }
                    }
                    if pickedImage != nil || hadImage {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("透明度").font(.system(size: 13))
                                Spacer()
                                Text("\(Int(imgOpacity))%")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .monospacedDigit()
                            }
                            Slider(value: $imgOpacity, in: 10...100, step: 5)
                        }
                        Button("移除图片", role: .destructive) {
                            pickedImage = nil
                            hadImage = false
                        }
                    }
                }
                if event != nil {
                    Section {
                        Button("删除事件", role: .destructive) { delete() }
                    }
                }
            }
            .navigationTitle(event == nil ? "添加事件" : "编辑事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: setup)
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data)?.resized(max: 1200),
                       let jpeg = img.jpegData(compressionQuality: 0.82) {
                        pickedImage = UIImage(data: jpeg)
                    }
                }
            }
        }
    }

    func setup() {
        guard let ev = event else { return }
        name = ev.name
        date = DayMath.parse(ev.date) ?? Date()
        type = ev.type
        repeatYearly = ev.repeatYearly
        colorIndex = ev.colorIndex
        hadImage = ev.imageFile != nil
        imgOpacity = Double(ev.imgOpacity ?? 100)
    }

    func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let dateStr = f.string(from: date)

        var list = Store.loadEvents()
        if var ev = event {
            guard let idx = list.firstIndex(where: { $0.id == ev.id }) else { dismiss(); return }
            if pickedImage == nil && !hadImage, let old = ev.imageFile { Store.deleteImage(old) }
            ev.name = trimmed
            ev.date = dateStr
            ev.type = type
            ev.repeatYearly = repeatYearly
            ev.colorIndex = colorIndex
            ev.imgOpacity = Int(imgOpacity)
            if let img = pickedImage, let jpeg = img.jpegData(compressionQuality: 0.82) {
                Store.deleteImage(ev.imageFile)
                ev.imageFile = Store.saveImage(jpeg)
            } else if pickedImage == nil && !hadImage {
                ev.imageFile = nil
            }
            list[idx] = ev
        } else {
            var ev = Event()
            ev.name = trimmed
            ev.date = dateStr
            ev.type = type
            ev.repeatYearly = repeatYearly
            ev.colorIndex = colorIndex
            ev.imgOpacity = Int(imgOpacity)
            if let img = pickedImage, let jpeg = img.jpegData(compressionQuality: 0.82) {
                ev.imageFile = Store.saveImage(jpeg)
            }
            ev.pinned = list.isEmpty
            ev.order = (list.map(\.order).max() ?? -1) + 1
            list.append(ev)
        }
        Store.saveEvents(list, reloadWidgets: true)
        dismiss()
    }

    func delete() {
        var list = Store.loadEvents()
        if let idx = list.firstIndex(where: { $0.id == event?.id }) {
            Store.deleteImage(list[idx].imageFile)
            list.remove(at: idx)
            if var first = list.first { first.pinned = true; list[0] = first }
        }
        Store.saveEvents(list, reloadWidgets: true)
        dismiss()
    }
}

// MARK: - 页面背景设置（图片 + 透明度）

struct BackgroundPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var opacity: Double = Double(Store.backgroundOpacity)
    @State private var hasImage = Store.loadBackgroundImage() != nil

    var body: some View {
        NavigationStack {
            Form {
                Section("页面背景图") {
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label(hasImage ? "更换背景图" : "从相册选择背景图", systemImage: "photo")
                    }
                    Button("移除背景图", role: .destructive) {
                        Store.saveBackgroundImage(nil)
                        hasImage = false
                    }
                    .disabled(!hasImage)
                }
                Section("透明度") {
                    HStack {
                        Text("\(Int(opacity))%")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .monospacedDigit()
                        Slider(value: $opacity, in: 5...100, step: 5) { _ in
                            Store.backgroundOpacity = Int(opacity)
                        }
                    }
                }
            }
            .navigationTitle("页面背景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        Store.backgroundOpacity = Int(opacity)
                        dismiss()
                    }
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data)?.resized(max: 1200),
                       let jpeg = img.jpegData(compressionQuality: 0.8) {
                        Store.saveBackgroundImage(jpeg)
                        hasImage = true
                    }
                }
            }
        }
    }
}

extension UIImage {
    func resized(max: CGFloat) -> UIImage {
        let scale = max / Swift.max(size.width, size.height)
        guard scale < 1 else { return self }
        let size = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
