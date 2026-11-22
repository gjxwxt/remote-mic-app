import AppKit
import Foundation

/// Central switch for the personal YK-8E00 fork build.
/// Keeps upstream files minimally modified while disabling official Sparkle self-updates
/// (which would overwrite the custom fork) and hiding unused commercial panels.
enum SkyworthPersonalEdition {
    static let isEnabled = true
}

/// Hardware-verified physical buttons on Skyworth YK-8E00 (VID 0x0094, PID 0x0013).
/// Kept separate from `RemoteButton` so upstream Xiaomi/Siri/Chromecast enums remain untouched.
enum SkyworthButton: String, CaseIterable, Codable, Identifiable, Hashable {
    case power
    case input
    case up
    case left
    case ok
    case right
    case down
    case back
    case home
    case menu
    case volumeUp = "volume_up"
    case volumeDown = "volume_down"
    case multitask
    case quickDots = "quick_dots"

    var id: String { rawValue }

    /// Bridge to `RemoteButton` for onboarding checks without mislabeling YK-8E00-only keys.
    var legacyRemoteButton: RemoteButton? {
        switch self {
        case .power: return .power
        case .input: return .input
        case .up: return .up
        case .left: return .left
        case .ok: return .ok
        case .right: return .right
        case .down: return .down
        case .back: return .back
        case .home: return .home
        case .menu: return .menu
        case .volumeUp: return .volumeUp
        case .volumeDown: return .volumeDown
        case .multitask: return nil
        case .quickDots: return nil
        }
    }

    var hidCodeLabel: String {
        switch self {
        case .power: return "0x66"
        case .input: return "0xA0"
        case .up: return "0x52"
        case .left: return "0x50"
        case .ok: return "0x96"
        case .right: return "0x4F"
        case .down: return "0x51"
        case .back: return "0xF1"
        case .home: return "Consumer"
        case .menu: return "0x65"
        case .volumeUp: return "0x80"
        case .volumeDown: return "0x81"
        case .multitask: return "0xC9"
        case .quickDots: return "0xCA"
        }
    }

    var symbolName: String {
        switch self {
        case .power: return "power"
        case .input: return "rectangle.portrait.and.arrow.right"
        case .up: return "chevron.up"
        case .left: return "chevron.left"
        case .ok: return "circle.inset.filled"
        case .right: return "chevron.right"
        case .down: return "chevron.down"
        case .back: return "arrow.uturn.backward"
        case .home: return "house"
        case .menu: return "line.3.horizontal"
        case .volumeUp: return "speaker.plus"
        case .volumeDown: return "speaker.minus"
        case .multitask: return "square.on.square"
        case .quickDots: return "ellipsis"
        }
    }

    func displayName(using localization: LocalizationStore) -> String {
        switch self {
        case .power: return localization.text("remote.button.full.power")
        case .input: return localization.text("remote.button.full.input")
        case .up: return localization.text("remote.button.full.up")
        case .left: return localization.text("remote.button.full.left")
        case .ok: return localization.text("remote.button.full.ok")
        case .right: return localization.text("remote.button.full.right")
        case .down: return localization.text("remote.button.full.down")
        case .back: return localization.text("remote.button.full.back")
        case .home: return localization.text("remote.button.full.home")
        case .menu: return localization.text("remote.button.full.menu")
        case .volumeUp: return localization.text("remote.button.full.volume_up")
        case .volumeDown: return localization.text("remote.button.full.volume_down")
        case .multitask: return localization.text("skyworth.button.multitask")
        case .quickDots: return localization.text("skyworth.button.quick_dots")
        }
    }

    func shortLabel(using localization: LocalizationStore) -> String {
        switch self {
        case .power: return localization.text("remote.button.short.power")
        case .input: return localization.text("remote.button.short.input")
        case .up: return localization.text("remote.button.short.up")
        case .left: return localization.text("remote.button.short.left")
        case .ok: return "OK"
        case .right: return localization.text("remote.button.short.right")
        case .down: return localization.text("remote.button.short.down")
        case .back: return localization.text("remote.button.short.back")
        case .home: return localization.text("remote.button.short.home")
        case .menu: return localization.text("remote.button.short.menu")
        case .volumeUp: return "+"
        case .volumeDown: return "−"
        case .multitask: return localization.text("skyworth.button.multitask")
        case .quickDots: return localization.text("skyworth.button.quick_dots")
        }
    }
}

enum SkyworthGesture: String, CaseIterable, Codable, Identifiable, Hashable {
    case singleClick = "single_click"
    case doubleClick = "double_click"
    case longPress = "long_press"

    var id: String { rawValue }

    func displayName(using localization: LocalizationStore) -> String {
        switch self {
        case .singleClick: return localization.text("skyworth.gesture.single")
        case .doubleClick: return localization.text("skyworth.gesture.double")
        case .longPress: return localization.text("skyworth.gesture.long")
        }
    }
}

enum SkyworthButtonBinding: Codable, Equatable {
    case native
    case action(ButtonAction)
    case customShortcut(CustomKeyboardShortcut)

    var configuredAction: ConfiguredButtonAction? {
        switch self {
        case .native:
            return nil
        case .action(let action):
            guard action != .disabled else { return nil }
            return ConfiguredButtonAction(action: action, shortcut: nil)
        case .customShortcut(let shortcut):
            return ConfiguredButtonAction(action: .customShortcut, shortcut: shortcut)
        }
    }

    var isCustom: Bool {
        if case .native = self { return false }
        return true
    }

    func displayName(using localization: LocalizationStore) -> String {
        switch self {
        case .native:
            return localization.text("skyworth.binding.native")
        case .action(let action):
            return action.displayName(using: localization)
        case .customShortcut(let shortcut):
            return shortcut.displayName(using: localization)
        }
    }
}

struct SkyworthButtonGestures: Codable, Equatable {
    var singleClick: SkyworthButtonBinding
    var doubleClick: SkyworthButtonBinding?
    var longPress: SkyworthButtonBinding?

    init(
        singleClick: SkyworthButtonBinding = .native,
        doubleClick: SkyworthButtonBinding? = nil,
        longPress: SkyworthButtonBinding? = nil
    ) {
        self.singleClick = singleClick
        self.doubleClick = doubleClick
        self.longPress = longPress
    }

    var hasDoubleClick: Bool {
        doubleClick?.configuredAction != nil
    }

    var hasLongPress: Bool {
        longPress?.configuredAction != nil
    }

    func binding(for gesture: SkyworthGesture) -> SkyworthButtonBinding? {
        switch gesture {
        case .singleClick: return singleClick
        case .doubleClick: return doubleClick
        case .longPress: return longPress
        }
    }

    mutating func setBinding(_ binding: SkyworthButtonBinding?, for gesture: SkyworthGesture) {
        switch gesture {
        case .singleClick:
            singleClick = binding ?? .native
        case .doubleClick:
            doubleClick = (binding?.isCustom == true) ? binding : nil
        case .longPress:
            longPress = (binding?.isCustom == true) ? binding : nil
        }
    }
}

struct SkyworthAppProfile: Codable, Equatable, Identifiable {
    let bundleIdentifier: String
    var displayName: String
    /// Per-button overrides keyed by `SkyworthButton.rawValue`. Unlisted buttons inherit Global.
    var overrides: [String: SkyworthButtonGestures]

    var id: String { bundleIdentifier }

    init(
        bundleIdentifier: String,
        displayName: String,
        overrides: [String: SkyworthButtonGestures] = [:]
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.overrides = overrides
    }
}

struct SkyworthMappingConfiguration: Codable, Equatable {
    var global: [String: SkyworthButtonGestures]
    var appProfiles: [SkyworthAppProfile]

    init(
        global: [String: SkyworthButtonGestures] = SkyworthButtonMappingStore.defaultGlobalRawMappings,
        appProfiles: [SkyworthAppProfile] = []
    ) {
        self.global = global
        self.appProfiles = appProfiles
    }

    func globalGestures(for button: SkyworthButton) -> SkyworthButtonGestures {
        global[button.rawValue]
            ?? SkyworthButtonMappingStore.defaultGestures[button]
            ?? SkyworthButtonGestures()
    }

    func hasOverride(for button: SkyworthButton, inApp bundleIdentifier: String) -> Bool {
        appProfiles.first(where: { $0.bundleIdentifier == bundleIdentifier })?
            .overrides[button.rawValue] != nil
    }

    func resolvedGestures(
        for button: SkyworthButton,
        frontmostBundleID: String?
    ) -> SkyworthButtonGestures {
        if let bundleID = frontmostBundleID,
           let profile = appProfiles.first(where: { $0.bundleIdentifier == bundleID }),
           let override = profile.overrides[button.rawValue] {
            return override
        }
        return globalGestures(for: button)
    }

    mutating func setBinding(
        _ binding: SkyworthButtonBinding?,
        for button: SkyworthButton,
        gesture: SkyworthGesture,
        appBundleID: String?
    ) {
        if let appBundleID,
           let index = appProfiles.firstIndex(where: { $0.bundleIdentifier == appBundleID }) {
            var current = appProfiles[index].overrides[button.rawValue] ?? globalGestures(for: button)
            current.setBinding(binding, for: gesture)
            appProfiles[index].overrides[button.rawValue] = current
        } else {
            var current = globalGestures(for: button)
            current.setBinding(binding, for: gesture)
            global[button.rawValue] = current
        }
    }

    mutating func clearOverride(for button: SkyworthButton, appBundleID: String) {
        guard let index = appProfiles.firstIndex(where: { $0.bundleIdentifier == appBundleID }) else { return }
        appProfiles[index].overrides.removeValue(forKey: button.rawValue)
    }
}

struct SkyworthActionPresetGroup: Identifiable {
    let id: String
    let titleKey: String
    let actions: [ButtonAction]
}

enum SkyworthButtonMappingStore {
    static let v1DefaultsKey = "skyworth.yk8e00.buttonMappings.v1"
    static let v2DefaultsKey = "skyworth.yk8e00.buttonMappings.v2"

    static let defaultGestures: [SkyworthButton: SkyworthButtonGestures] = [
        .power: SkyworthButtonGestures(singleClick: .native),
        .input: SkyworthButtonGestures(singleClick: .action(.openRemoteMic)),
        .up: SkyworthButtonGestures(singleClick: .native),
        .left: SkyworthButtonGestures(singleClick: .native),
        .ok: SkyworthButtonGestures(singleClick: .action(.returnKey), longPress: .action(.commandReturn)),
        .right: SkyworthButtonGestures(singleClick: .native),
        .down: SkyworthButtonGestures(singleClick: .native),
        .back: SkyworthButtonGestures(singleClick: .action(.escape), longPress: .action(.deleteBackward)),
        .home: SkyworthButtonGestures(singleClick: .native),
        .menu: SkyworthButtonGestures(singleClick: .action(.commandUndo), longPress: .action(.commandRedo)),
        .volumeUp: SkyworthButtonGestures(singleClick: .native),
        .volumeDown: SkyworthButtonGestures(singleClick: .native),
        .multitask: SkyworthButtonGestures(singleClick: .action(.missionControl), longPress: .action(.showDesktop)),
        .quickDots: SkyworthButtonGestures(singleClick: .action(.appSwitcher), longPress: .action(.screenshot)),
    ]

    static var defaultGlobalRawMappings: [String: SkyworthButtonGestures] {
        Dictionary(uniqueKeysWithValues: defaultGestures.map { ($0.key.rawValue, $0.value) })
    }

    static let presetGroups: [SkyworthActionPresetGroup] = [
        SkyworthActionPresetGroup(
            id: "editing",
            titleKey: "skyworth.group.editing",
            actions: [
                .returnKey, .commandReturn, .shiftReturn, .escape,
                .deleteBackward, .commandUndo, .commandRedo,
                .commandCopy, .commandPaste, .commandCut, .commandSelectAll,
                .commandSave, .commandFind,
            ]
        ),
        SkyworthActionPresetGroup(
            id: "window",
            titleKey: "skyworth.group.window",
            actions: [
                .appSwitcher, .missionControl, .applicationWindows, .showDesktop,
                .spaceLeft, .spaceRight, .commandNextWindow, .commandHide,
                .commandMinimize, .toggleFullScreen, .commandNewTab,
                .commandPreviousTab, .commandNextTab, .commandClose,
            ]
        ),
        SkyworthActionPresetGroup(
            id: "navigation",
            titleKey: "skyworth.group.navigation",
            actions: [
                .arrowUp, .arrowDown, .arrowLeft, .arrowRight,
                .scrollUp, .scrollDown, .pageUp, .pageDown,
                .scrollToTop, .scrollToBottom, .contextMenu,
            ]
        ),
        SkyworthActionPresetGroup(
            id: "media",
            titleKey: "skyworth.group.media",
            actions: [
                .playPause, .volumeUp, .volumeDown, .volumeMute,
                .screenshot, .lockScreen,
            ]
        ),
        SkyworthActionPresetGroup(
            id: "sayall",
            titleKey: "skyworth.group.sayall",
            actions: [
                .openRemoteMic, .openCommonPhrases, .toggleLongRecording,
            ]
        ),
    ]

    static func loadConfiguration(from defaults: UserDefaults = .standard) -> SkyworthMappingConfiguration {
        if let data = defaults.data(forKey: v2DefaultsKey),
           var decoded = try? JSONDecoder().decode(SkyworthMappingConfiguration.self, from: data) {
            for (button, gestures) in defaultGestures where decoded.global[button.rawValue] == nil {
                decoded.global[button.rawValue] = gestures
            }
            return decoded
        }

        // Migrate v1 single-click mappings if present.
        var config = SkyworthMappingConfiguration()
        if let v1Data = defaults.data(forKey: v1DefaultsKey),
           let v1 = try? JSONDecoder().decode([String: SkyworthButtonBinding].self, from: v1Data) {
            for (rawKey, binding) in v1 {
                if let button = SkyworthButton(rawValue: rawKey) {
                    var gestures = config.globalGestures(for: button)
                    gestures.singleClick = binding
                    config.global[rawKey] = gestures
                }
            }
        }
        return config
    }

    static func saveConfiguration(
        _ config: SkyworthMappingConfiguration,
        to defaults: UserDefaults = .standard
    ) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: v2DefaultsKey)
        }
    }
}

/// Zero-lag gesture recognizer for YK-8E00 buttons.
/// - No double-click & no long-press configured -> fires `.singleClick` immediately on press.
/// - Long-press configured -> fires `.longPress` at `longPressDuration` while held, or `.singleClick` on early release.
/// - Double-click configured -> waits `doubleClickWindow` after first release; second press fires `.doubleClick`.
final class SkyworthGestureRecognizer {
    let doubleClickWindow: TimeInterval
    let longPressDuration: TimeInterval
    var onTrigger: ((SkyworthButton, SkyworthGesture) -> Void)?

    private var activePressGestures: [SkyworthButton: SkyworthButtonGestures] = [:]
    private var longPressWork: [SkyworthButton: DispatchWorkItem] = [:]
    private var longPressFired: Set<SkyworthButton> = []
    private var pendingSingleClickWork: [SkyworthButton: DispatchWorkItem] = [:]

    init(doubleClickWindow: TimeInterval = 0.26, longPressDuration: TimeInterval = 0.42) {
        self.doubleClickWindow = doubleClickWindow
        self.longPressDuration = longPressDuration
    }

    func handlePress(button: SkyworthButton, gestures: SkyworthButtonGestures) {
        if let pendingSingle = pendingSingleClickWork.removeValue(forKey: button) {
            pendingSingle.cancel()
            activePressGestures.removeValue(forKey: button)
            longPressFired.insert(button) // Consume matching release
            onTrigger?(button, .doubleClick)
            return
        }

        if !gestures.hasDoubleClick && !gestures.hasLongPress {
            onTrigger?(button, .singleClick)
            return
        }

        activePressGestures[button] = gestures
        longPressFired.remove(button)

        if gestures.hasLongPress {
            longPressWork[button]?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.activePressGestures[button] != nil else { return }
                self.longPressWork.removeValue(forKey: button)
                self.longPressFired.insert(button)
                self.onTrigger?(button, .longPress)
            }
            longPressWork[button] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + longPressDuration, execute: work)
        }
    }

    func handleRelease(button: SkyworthButton) {
        longPressWork.removeValue(forKey: button)?.cancel()
        if longPressFired.remove(button) != nil {
            activePressGestures.removeValue(forKey: button)
            return
        }
        guard let gestures = activePressGestures.removeValue(forKey: button) else { return }

        if gestures.hasDoubleClick {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingSingleClickWork.removeValue(forKey: button)
                self.onTrigger?(button, .singleClick)
            }
            pendingSingleClickWork[button] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleClickWindow, execute: work)
        } else {
            onTrigger?(button, .singleClick)
        }
    }

    func reset() {
        longPressWork.values.forEach { $0.cancel() }
        longPressWork.removeAll()
        pendingSingleClickWork.values.forEach { $0.cancel() }
        pendingSingleClickWork.removeAll()
        activePressGestures.removeAll()
        longPressFired.removeAll()
    }
}
