import AppKit
import AVFoundation
import SwiftUI
import Vision

let awayKey = "awaySeconds"
// calibrate: shorter locks you out when you just look away or lean back
let defaultAwaySeconds: TimeInterval = 8
// after Annulla: long enough to look at your phone without the warning coming straight back
let snoozeSeconds: TimeInterval = 30

/// Absence countdown over the analysed frames.
struct Presence {
    var lastSeen = Date.distantPast
    var lastFrame = Date.distantPast
    var snoozeUntil = Date.distantPast

    /// Seconds left before locking: nil while you're here, 0 means lock now.
    mutating func countdown(seen: Bool, at now: Date, away: TimeInterval) -> TimeInterval? {
        defer { lastFrame = now }
        // a gap in frames (sleep, lock, pause) restarts the countdown; Annulla counts as being seen
        if seen || now < snoozeUntil || now.timeIntervalSince(lastFrame) > 5 { lastSeen = now; return nil }
        let left = away - now.timeIntervalSince(lastSeen)
        if left <= 0 { lastSeen = now }  // don't fire again on every frame while the lock kicks in
        return max(left, 0)
    }
}

// Private API in login.framework: locks like ⌃⌘Q, without needing Accessibility permission.
func lockSymbol() -> UnsafeMutableRawPointer? {
    dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        .flatMap { dlsym($0, "SACLockScreenImmediate") }
}

func lockScreen() {
    if let sym = lockSymbol() {
        _ = unsafeBitCast(sym, to: (@convention(c) () -> Int32).self)()
    } else {
        // fallback if Apple removes the symbol: locks only with "Require password immediately" on
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/pmset"), arguments: ["displaysleepnow"])
    }
}

final class Watcher: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "presenza.camera")
    var presence = Presence()  // touched only on `queue`
    var onCountdown: (TimeInterval?) -> Void = { _ in }  // called on main

    func configure() -> Bool {
        // built-in camera first, so an iPhone Continuity Camera isn't picked up by accident
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: cam), session.canAddInput(input) else { return false }
        session.addInput(input)
        if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        return true
    }

    func start() { queue.async { self.session.startRunning() } }
    // fresh state on restart: the camera's dark warm-up frames must not count as "gone"
    func stop() { queue.async { self.session.stopRunning(); self.presence = Presence() } }
    func snooze() { queue.async { self.presence.snoozeUntil = Date() + snoozeSeconds } }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(presence.lastFrame) >= 1 else { return }  // ~1 analysis/s is plenty
        let face = VNDetectFaceRectanglesRequest()
        let body = VNDetectHumanRectanglesRequest()  // head + shoulders: still sees you when you turn away
        // a Vision error means "don't know", never "nobody here"
        guard (try? VNImageRequestHandler(cmSampleBuffer: buffer, options: [:]).perform([face, body])) != nil else { return }
        let seen = !(face.results ?? []).isEmpty || !(body.results ?? []).isEmpty
        // floor: a hand-edited 0 would lock on the first missed frame
        let away = max(3, UserDefaults.standard.double(forKey: awayKey))
        let left = presence.countdown(seen: seen, at: now, away: away)
        DispatchQueue.main.async { self.onCountdown(left) }
    }
}

// MARK: - Warning that grows out of the notch

@Observable final class IslandModel {
    var secondsLeft: Int?
    var notch: CGFloat = 0
    var onCancel: () -> Void = {}
}

struct IslandView: View {
    let model: IslandModel

    var body: some View {
        VStack {
            if let seconds = model.secondsLeft {
                HStack(spacing: 14) {
                    Image(systemName: "faceid")
                        .font(.system(size: 22))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Te ne stai andando?").fontWeight(.semibold)
                        Text("Blocco lo schermo tra \(seconds) s")
                            .foregroundStyle(.white.opacity(0.7))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                    Button(action: model.onCancel) {
                        Text("Annulla")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.2), in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.top, model.notch + 10)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
                // flush with the top edge: on a notched screen it reads as the notch getting bigger
                .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
                .transition(.scale(scale: 0.4, anchor: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.35, bounce: 0.25), value: model.secondsLeft)
    }
}

/// The panel never becomes active: without this the first click would only "activate" it.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class Island {
    static let size = NSSize(width: 520, height: 140)
    let model = IslandModel()
    let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar  // above the menu bar, so it can cover the notch
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        let view = FirstMouseHostingView(rootView: IslandView(model: model))
        view.sizingOptions = []
        view.autoresizingMask = [.width, .height]
        panel.contentView = view
    }

    func show(_ seconds: Int) {
        // on the screen you're working on (where the pointer is)
        if model.secondsLeft == nil,
           let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            model.notch = screen.safeAreaInsets.top
            let s = Self.size, f = screen.frame
            panel.setFrame(NSRect(x: f.midX - s.width / 2, y: f.maxY - s.height, width: s.width, height: s.height), display: true)
            panel.orderFrontRegardless()
        }
        model.secondsLeft = seconds
    }

    func hide() {
        guard model.secondsLeft != nil else { return }
        model.secondsLeft = nil
        // after the closing animation, unless it came back meanwhile
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if self.model.secondsLeft == nil { self.panel.orderOut(nil) }
        }
    }
}

// MARK: - App

final class App: NSObject, NSApplicationDelegate {
    let watcher = Watcher()
    let island = Island()
    var item: NSStatusItem!
    var settings: NSWindow?
    var paused = false

    func applicationDidFinishLaunching(_ note: Notification) {
        UserDefaults.standard.register(defaults: [awayKey: defaultAwaySeconds])

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "Pausa"), action: #selector(togglePause), keyEquivalent: "p").target = self
        menu.addItem(withTitle: String(localized: "Blocca ora"), action: #selector(lockNow), keyEquivalent: "l").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Impostazioni…"), action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Esci da Presenza"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        updateIcon()

        island.model.onCancel = {
            self.watcher.snooze()
            self.island.hide()
        }
        watcher.onCountdown = { left in
            guard let left, !self.paused else { return self.island.hide() }
            if left > 0 { return self.island.show(Int(left.rounded(.up))) }
            self.island.hide()
            lockScreen()
        }

        // camera off while locked: green light off, no frames analysed behind the lock screen
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            self.watcher.stop()
            self.island.hide()
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            if !self.paused { self.watcher.start() }
        }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                guard granted, self.watcher.configure() else {
                    return self.fail(String(localized: "Presenza non può usare la fotocamera. Abilitala in Impostazioni di Sistema › Privacy e sicurezza › Fotocamera, poi riapri l'app."))
                }
                self.watcher.start()
            }
        }
    }

    @objc func togglePause(_ sender: NSMenuItem) {
        paused.toggle()
        sender.title = paused ? String(localized: "Riprendi") : String(localized: "Pausa")
        if paused {
            watcher.stop()
            island.hide()
        } else {
            watcher.start()
        }
        updateIcon()
    }

    @objc func lockNow() { lockScreen() }

    @objc func openSettings() {
        if settings == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = String(localized: "Impostazioni di Presenza")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        NSApp.activate()
        settings?.makeKeyAndOrderFront(nil)
    }

    func updateIcon() {
        item.button?.image = NSImage(systemSymbolName: paused ? "eye.slash" : "eye",
                                     accessibilityDescription: paused ? String(localized: "Presenza in pausa") : String(localized: "Presenza attiva"))
    }

    func fail(_ message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        NSApp.terminate(nil)
    }
}

if CommandLine.arguments.contains("--selftest") {
    var p = Presence()
    let t0 = Date(timeIntervalSinceReferenceDate: 0)  // round numbers, so the seconds compare exactly
    let away = defaultAwaySeconds
    // seen for 10 s, then gone: countdown from the first miss, lock `away` seconds after the last sighting
    let n = 10 + Int(away)
    let left = (0..<n).map { p.countdown(seen: $0 < 10, at: t0 + TimeInterval($0), away: away) }
    precondition(left[9] == nil && left[10] == away - 1 && left[n - 1] == 0, "countdown: \(left)")
    p.snoozeUntil = t0 + TimeInterval(n + 5)
    precondition(p.countdown(seen: false, at: t0 + TimeInterval(n), away: away) == nil, "Annulla must hold off the countdown")
    precondition(p.countdown(seen: false, at: t0 + 100, away: away) == nil, "a gap in frames must restart the countdown")
    precondition(lockSymbol() != nil, "SACLockScreenImmediate not found: locking would fall back to pmset")
    // without the (empty) Italian table macOS shows English even when Italian is chosen
    precondition(["it", "en"].allSatisfy { Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: $0) != nil },
                 "the bundle must carry a Localizable.strings for both Italian and English")
    print("selftest ok")
    exit(0)
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
