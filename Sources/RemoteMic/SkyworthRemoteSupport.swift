import AppKit
import Foundation

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

struct SkyworthActionPresetGroup: Identifiable {
    let id: String
    let titleKey: String
    let actions: [ButtonAction]
}

enum SkyworthButtonMappingStore {
    static let defaultsKey = "skyworth.yk8e00.buttonMappings.v1"

    static let defaultMappings: [SkyworthButton: SkyworthButtonBinding] = [
        .power: .native,
        .input: .action(.openRemoteMic),
        .up: .native,
        .left: .native,
        .ok: .action(.returnKey),
        .right: .native,
        .down: .native,
        .back: .action(.escape),
        .home: .native,
        .menu: .action(.commandUndo),
        .volumeUp: .native,
        .volumeDown: .native,
        .multitask: .action(.missionControl),
        .quickDots: .action(.appSwitcher),
    ]

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

    static func load(from defaults: UserDefaults = .standard) -> [SkyworthButton: SkyworthButtonBinding] {
        var resolved = defaultMappings
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: SkyworthButtonBinding].self, from: data)
        else {
            return resolved
        }
        for (rawKey, binding) in decoded {
            if let button = SkyworthButton(rawValue: rawKey) {
                resolved[button] = binding
            }
        }
        return resolved
    }

    static func save(
        _ mappings: [SkyworthButton: SkyworthButtonBinding],
        to defaults: UserDefaults = .standard
    ) {
        let encodedDict = Dictionary(
            uniqueKeysWithValues: mappings.map { ($0.key.rawValue, $0.value) }
        )
        if let data = try? JSONEncoder().encode(encodedDict) {
            defaults.set(data, forKey: defaultsKey)
        }
    }
}
