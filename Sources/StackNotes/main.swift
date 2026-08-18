import SwiftUI
import AppKit
import Combine

// MARK: - Model

struct NoteData: Codable, Identifiable, Equatable {
    var id: UUID
    var text: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var pinned: Bool = false

    enum CodingKeys: String, CodingKey { case id, text, x, y, width, height, pinned }

    init(id: UUID, text: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, pinned: Bool = false) {
        self.id = id; self.text = text; self.x = x; self.y = y
        self.width = width; self.height = height; self.pinned = pinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        x = try c.decode(CGFloat.self, forKey: .x)
        y = try c.decode(CGFloat.self, forKey: .y)
        width = try c.decode(CGFloat.self, forKey: .width)
        height = try c.decode(CGFloat.self, forKey: .height)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
    }
}

final class Store {
    static let shared = Store()
    let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("notes.json")
    }()

    func load() -> [NoteData] {
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([NoteData].self, from: data) else {
            return []
        }
        return items
    }

    func save(_ items: [NoteData]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Shared app state (drives both dashboard and notes)

final class AppState: ObservableObject {
    @Published var notes: [NoteData] = []
    @Published var glassVariant: Int = UserDefaults.standard.integer(forKey: "glassVariant") {
        didSet { UserDefaults.standard.set(glassVariant, forKey: "glassVariant") }
    }
    @Published var regularBgOpacity: CGFloat = {
        let v = UserDefaults.standard.object(forKey: "regularBgOpacity") as? Double
        return CGFloat(v ?? 0.5)
    }() {
        didSet { UserDefaults.standard.set(Double(regularBgOpacity), forKey: "regularBgOpacity") }
    }
    @Published var fontSize: CGFloat = {
        let v = UserDefaults.standard.object(forKey: "fontSize") as? Double
        return CGFloat(v ?? 14)
    }() {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: "fontSize") }
    }
    @Published var fontColor: Color = AppState.loadColor("fontColor", default: .white) {
        didSet { AppState.saveColor(fontColor, "fontColor") }
    }
    @Published var bgColor: Color = AppState.loadColor("bgColor", default: Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0)) {
        didSet { AppState.saveColor(bgColor, "bgColor") }
    }

    static func loadColor(_ key: String, default def: Color) -> Color {
        guard let arr = UserDefaults.standard.array(forKey: key) as? [Double], arr.count == 4 else { return def }
        return Color(.sRGB, red: arr[0], green: arr[1], blue: arr[2], opacity: arr[3])
    }
    static func saveColor(_ c: Color, _ key: String) {
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? NSColor.white
        UserDefaults.standard.set(
            [Double(ns.redComponent), Double(ns.greenComponent), Double(ns.blueComponent), Double(ns.alphaComponent)],
            forKey: key
        )
    }

    func upsert(_ s: NoteData) {
        if let i = notes.firstIndex(where: { $0.id == s.id }) {
            notes[i] = s
        } else {
            notes.append(s)
        }
        Store.shared.save(notes)
    }

    func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
        Store.shared.save(notes)
    }

    func note(_ id: UUID) -> NoteData? {
        notes.first { $0.id == id }
    }
}

// MARK: - Liquid Glass background

struct FrostedBackground: View {
    @ObservedObject var state: AppState
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let glass: Glass = (state.glassVariant == 1) ? .clear : .regular
        return ZStack {
            Color.clear.glassEffect(glass, in: shape)
            if state.glassVariant == 0 {
                state.bgColor.opacity(state.regularBgOpacity).clipShape(shape)
            }
        }
    }
}

// MARK: - Note view

struct NoteView: View {
    let id: UUID
    @ObservedObject var state: AppState
    let onClose: () -> Void
    let onDrag: () -> Void
    let onTogglePin: () -> Void
    @State private var hovering = false

    private var text: Binding<String> {
        Binding(
            get: { state.note(id)?.text ?? "" },
            set: { new in
                guard var s = state.note(id) else { return }
                s.text = new
                state.upsert(s)
            }
        )
    }

    private var isPinned: Bool { state.note(id)?.pinned ?? false }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar — drag handle
            ZStack {
                Color.black.opacity(0.55)
                HStack {
                    Button(action: onClose) {
                        Circle()
                            .fill(Color.white.opacity(hovering ? 1 : 0.7))
                            .frame(width: 11, height: 11)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .opacity(hovering ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: onTogglePin) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(isPinned ? 1 : (hovering ? 0.9 : 0.6)))
                            .rotationEffect(.degrees(isPinned ? 0 : 45))
                            .help(isPinned ? "Unpin" : "Keep on top")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 24)
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { _ in onDrag() }
            )

            // Body
            TextEditor(text: text)
                .font(.system(size: state.fontSize, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(10)
                .foregroundColor(state.fontColor)
        }
        .background(FrostedBackground(state: state, cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        .overlay(alignment: .bottomTrailing) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 12))
                p.addQuadCurve(to: CGPoint(x: 12, y: 0), control: CGPoint(x: 12, y: 12))
            }
            .stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            .frame(width: 12, height: 12)
            .padding(6)
            .allowsHitTesting(false)
        }
        .onHover { hovering = $0 }
    }
}

// MARK: - Note window

final class NoteWindow: NSWindow {
    let noteID: UUID

    init(data: NoteData, state: AppState, onClose: @escaping (UUID) -> Void, onTogglePin: @escaping (UUID) -> Void) {
        self.noteID = data.id
        super.init(
            contentRect: NSRect(x: data.x, y: data.y, width: data.width, height: data.height),
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Hide native chrome but keep titled-window resize behavior (edge/corner
        // hit testing + system cursors). The SwiftUI body draws the visible UI.
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true

        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false // SwiftUI provides shadow
        self.minSize = NSSize(width: 160, height: 140)
        applyPinned(data.pinned)

        let id = data.id
        let view = NoteView(
            id: id,
            state: state,
            onClose: { onClose(id) },
            onDrag: { [weak self] in
                guard let self, let event = NSApp.currentEvent else { return }
                self.performDrag(with: event)
            },
            onTogglePin: { onTogglePin(id) }
        )
        self.contentView = FirstMouseHostingView(rootView: view)
        installActiveBlurFix(on: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    // Keep Liquid Glass `.clear` from desaturating when another app takes
    // focus. Glass reads `isMainWindow` to decide active vs. inactive look.
    override var isMainWindow: Bool { true }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func applyPinned(_ pinned: Bool) {
        let wasVisible = self.isVisible
        if pinned {
            self.level = .floating
            self.collectionBehavior = [.stationary, .canJoinAllSpaces]
            if wasVisible { self.orderFrontRegardless() }
        } else {
            // Pull the window off whatever space it's currently joining (e.g. a
            // fullscreen app's space) and drop it behind other windows on its
            // home desktop space.
            self.level = .normal
            self.orderOut(nil)
            self.collectionBehavior = [.stationary]
            if wasVisible {
                self.orderBack(nil)
                self.resignKey()
            }
        }
    }

    /// Put a normal note behind the other windows on the desktop when the
    /// Stack app loses focus. Pinned notes intentionally stay floating.
    func moveBehindOtherWindows() {
        guard !isPinnedWindow else { return }
        orderBack(nil)
        resignKey()
    }

    private var isPinnedWindow: Bool {
        level == .floating
    }
}

// NSHostingView subclass that lets clicks reach the SwiftUI gestures even
// when the window is not key — so dragging a note by its title bar works
// on the very first mousedown instead of requiring an activation click first.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func layout() {
        super.layout()
        forceActiveVisualEffects(in: self)
    }
}

// Walk subview tree and force every NSVisualEffectView (including those the
// SwiftUI `.glassEffect` hosts) to stay active when the window loses focus.
func forceActiveVisualEffects(in view: NSView) {
    if let ve = view as? NSVisualEffectView {
        ve.state = .active
    }
    for sub in view.subviews { forceActiveVisualEffects(in: sub) }
}

// Window mixin: re-force active state whenever key/main status changes.
func installActiveBlurFix(on window: NSWindow) {
    let nc = NotificationCenter.default
    let apply: (Notification) -> Void = { _ in
        guard let v = window.contentView else { return }
        DispatchQueue.main.async { forceActiveVisualEffects(in: v) }
    }
    for name in [NSWindow.didResignKeyNotification, NSWindow.didResignMainNotification,
                 NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
        nc.addObserver(forName: name, object: window, queue: .main, using: apply)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @ObservedObject var state: AppState
    let onNew: () -> Void
    let onFocus: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onHide: () -> Void
    @State private var hoveredID: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stack")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(state.fontColor)
                Spacer()
                Button(action: onHide) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(state.fontColor.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Hide dashboard")
                Button(action: onNew) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Text("New")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.accentColor)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(Color.primary.opacity(0.15))

            if state.notes.isEmpty {
                VStack {
                    Spacer()
                    Text("No notes yet.\nTap + New to add one.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(state.fontColor.opacity(0.65))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(state.notes.enumerated()), id: \.element.id) { idx, s in
                            NoteRow(
                                s: s,
                                state: state,
                                onFocus: { onFocus(s.id) },
                                onDelete: { onDelete(s.id) },
                                onHover: { isHover in
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        hoveredID = isHover ? s.id : (hoveredID == s.id ? nil : hoveredID)
                                    }
                                }
                            )
                            if idx < state.notes.count - 1 {
                                let next = state.notes[idx + 1].id
                                let hidden = hoveredID == s.id || hoveredID == next
                                Rectangle()
                                    .fill(Color.primary.opacity(hidden ? 0 : 0.08))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                    .padding(10)
                }
            }

            Divider().background(Color.primary.opacity(0.15))

            SettingsPanel(state: state)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            Divider().background(Color.primary.opacity(0.15))

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 10))
                    .foregroundColor(state.fontColor.opacity(0.65))
                Text(Store.shared.url.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(state.fontColor.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(Store.shared.url.path)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                NSWorkspace.shared.activateFileViewerSelecting([Store.shared.url])
            }
        }
        .background(FrostedBackground(state: state, cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        .padding(10)
    }
}

struct NoteRow: View {
    let s: NoteData
    @ObservedObject var state: AppState
    let onFocus: () -> Void
    let onDelete: () -> Void
    var onHover: (Bool) -> Void = { _ in }
    @State private var hover = false

    private var preview: String {
        let trimmed = s.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(empty)" : trimmed
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.primary.opacity(0.7)).frame(width: 6, height: 6)
            Text(preview)
                .lineLimit(1)
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(state.fontColor)
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(state.fontColor)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .opacity(hover ? 1 : 0)
            .allowsHitTesting(hover)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(hover ? 0.12 : 0))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onFocus)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.18)) { hover = h }
            onHover(h)
        }
    }
}

struct SettingsPanel: View {
    @ObservedObject var state: AppState
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Appearance")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Spacer()
                }
                .foregroundColor(state.fontColor.opacity(0.7))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Group {
                    sectionLabel("Text")
                    sliderRow("textformat.size", Binding(
                        get: { (state.fontSize - 10) / 14 },
                        set: { state.fontSize = 10 + $0 * 14 }
                    ))
                    colorRow(icon: "paintpalette", label: "Font color", selection: $state.fontColor)

                    Divider().padding(.vertical, 4)

                    sectionLabel("Background")
                    Picker("", selection: $state.glassVariant) {
                        Text("Regular").tag(0)
                        Text("Clear").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    if state.glassVariant == 0 {
                        colorRow(icon: "paintbrush", label: "Background color", selection: $state.bgColor)
                        sliderRow("circle.lefthalf.filled", $state.regularBgOpacity)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundColor(state.fontColor.opacity(0.55))
            .tracking(0.5)
            .padding(.top, 2)
    }

    private func colorRow(icon: String, label: String, selection: Binding<Color>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(state.fontColor.opacity(0.6))
                .frame(width: 12)
            ColorPicker(label, selection: selection, supportsOpacity: true)
                .labelsHidden()
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(state.fontColor.opacity(0.65))
            Spacer()
        }
    }

    private func sliderRow(_ icon: String, _ binding: Binding<CGFloat>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(state.fontColor.opacity(0.6))
                .frame(width: 12)
            Slider(value: Binding(
                get: { Double(binding.wrappedValue) },
                set: { binding.wrappedValue = CGFloat($0) }
            ), in: 0...1)
            .controlSize(.mini)
        }
    }
}

final class DashboardWindow: NSWindow {
    init(rootView: NSView) {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 280, height: 360),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .normal
        self.isMovableByWindowBackground = true
        self.collectionBehavior = []
        self.minSize = NSSize(width: 240, height: 240)
        self.contentView = rootView
        installActiveBlurFix(on: self)
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var isMainWindow: Bool { true }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private var noteWindows: [UUID: NoteWindow] = [:]
    private var dashboard: DashboardWindow?
    private var statusItem: NSStatusItem!
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        installEditMenu()

        // Menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Stack")
            b.image?.isTemplate = true
        }
        let menu = NSMenu()
        let mNew = NSMenuItem(title: "New Note", action: #selector(menuNew), keyEquivalent: "n")
        mNew.target = self
        menu.addItem(mNew)
        let mDash = NSMenuItem(title: "Show / Hide Dashboard", action: #selector(toggleDashboard), keyEquivalent: "d")
        mDash.target = self
        menu.addItem(mDash)
        menu.addItem(.separator())
        let mQuit = NSMenuItem(title: "Quit Stack", action: #selector(menuQuit), keyEquivalent: "q")
        mQuit.target = self
        menu.addItem(mQuit)
        statusItem.menu = menu

        // Load
        state.notes = Store.shared.load()
        for s in state.notes { spawnWindow(for: s) }

        // Dashboard
        showDashboard()

        // Keep window frames in sync
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: NSWindow.didMoveNotification, object: nil, queue: .main) { [weak self] n in
            self?.syncFrame(n)
        })
        observers.append(nc.addObserver(forName: NSWindow.didResizeNotification, object: nil, queue: .main) { [weak self] n in
            self?.syncFrame(n)
        })
        // Reposition color panel next to dashboard whenever it appears.
        observers.append(nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] n in
            guard let panel = n.object as? NSColorPanel, let dash = self?.dashboard else { return }
            let d = dash.frame
            let p = panel.frame
            var x = d.minX - p.width - 8
            if x < 8 { x = d.maxX + 8 }
            let y = max(8, d.maxY - p.height)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        })
        observers.append(nc.addObserver(forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main) { [weak self] _ in
            self?.sendNotesToBack()
        })
    }

    func applicationWillTerminate(_ notification: Notification) {
        Store.shared.save(state.notes)
    }

    @objc func menuNew() { newNote() }
    @objc func menuQuit() { NSApp.terminate(nil) }

    /// The accessory app has no default application menu. Without an Edit
    /// menu, AppKit does not route the standard Command-X/C/V actions from a
    /// TextEditor through the responder chain.
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem(title: "Stack", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Stack", action: #selector(menuQuit), keyEquivalent: "q").target = self
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    @objc func toggleDashboard() {
        if let d = dashboard, d.isVisible {
            d.orderOut(nil)
        } else {
            showDashboard()
        }
    }

    private func showDashboard() {
        if dashboard == nil {
            let host = NSHostingView(rootView: DashboardView(
                state: state,
                onNew: { [weak self] in self?.newNote() },
                onFocus: { [weak self] id in self?.focusNote(id) },
                onDelete: { [weak self] id in self?.deleteNote(id) },
                onHide: { [weak self] in self?.dashboard?.orderOut(nil) }
            ))
            host.frame = NSRect(x: 0, y: 0, width: 280, height: 360)
            host.autoresizingMask = [.width, .height]
            dashboard = DashboardWindow(rootView: host)
            if let screen = NSScreen.main {
                let f = screen.visibleFrame
                dashboard?.setFrameOrigin(NSPoint(x: f.maxX - 300, y: f.maxY - 380))
            }
        }
        dashboard?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func newNote() {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 200, y: 200, width: 240, height: 200)
        let s = NoteData(
            id: UUID(),
            text: "",
            x: frame.midX - 120 + CGFloat.random(in: -80...80),
            y: frame.midY - 100 + CGFloat.random(in: -80...80),
            width: 240, height: 200
        )
        state.upsert(s)
        spawnWindow(for: s)
    }

    private func spawnWindow(for s: NoteData) {
        let w = NoteWindow(
            data: s,
            state: state,
            onClose: { [weak self] id in self?.closeNoteWindow(id) },
            onTogglePin: { [weak self] id in self?.togglePin(id) }
        )
        noteWindows[s.id] = w
        w.orderFrontRegardless()
    }

    private func togglePin(_ id: UUID) {
        guard var s = state.note(id) else { return }
        s.pinned.toggle()
        state.upsert(s)
        noteWindows[id]?.applyPinned(s.pinned)
    }

    private func closeNoteWindow(_ id: UUID) {
        // Respect an explicitly hidden dashboard. Closing a note should not
        // unexpectedly bring the menu window back after the user clicked the
        // eye button.
        let dashboardWasVisible = dashboard?.isVisible == true
        if let w = noteWindows.removeValue(forKey: id) {
            w.orderOut(nil)
        }
        if dashboardWasVisible {
            showDashboard()
        }
    }

    private func focusNote(_ id: UUID) {
        if let w = noteWindows[id] {
            w.orderFrontRegardless()
            w.makeKey()
            return
        }
        guard let s = state.note(id) else { return }
        spawnWindow(for: s)
        noteWindows[id]?.makeKey()
    }

    private func sendNotesToBack() {
        for window in noteWindows.values {
            window.moveBehindOtherWindows()
        }
    }

    private func deleteNote(_ id: UUID) {
        if let w = noteWindows.removeValue(forKey: id) {
            w.orderOut(nil)
            w.close()
        }
        state.remove(id)
    }

    private func syncFrame(_ notification: Notification) {
        guard let w = notification.object as? NoteWindow else { return }
        guard var s = state.note(w.noteID) else { return }
        let f = w.frame
        s.x = f.origin.x; s.y = f.origin.y
        s.width = f.size.width; s.height = f.size.height
        state.upsert(s)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
