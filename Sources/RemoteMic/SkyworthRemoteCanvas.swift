import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SkyworthCanvasPlacement: Identifiable {
    let button: SkyworthButton
    let side: RemoteMappingSide
    /// Normalized point inside the center YK-8E00 remote body (0...1).
    let anchor: UnitPoint
    /// Normalized vertical position along the canvas height (0...1).
    let targetY: CGFloat

    var id: SkyworthButton { button }
}

enum SkyworthCanvasLayout {
    static let canvasHeight: CGFloat = 640
    static let remoteSize = CGSize(width: 210, height: 530)
    static let arrowCardGap: CGFloat = 6

    static let voiceAnchor = UnitPoint(x: 0.50, y: 0.178)
    static let voiceTargetY: CGFloat = 0.062

    static let placements: [SkyworthCanvasPlacement] = [
        // Left column (7 buttons)
        SkyworthCanvasPlacement(button: .power, side: .left, anchor: UnitPoint(x: 0.28, y: 0.088), targetY: 0.080),
        SkyworthCanvasPlacement(button: .input, side: .left, anchor: UnitPoint(x: 0.72, y: 0.088), targetY: 0.215),
        SkyworthCanvasPlacement(button: .up, side: .left, anchor: UnitPoint(x: 0.50, y: 0.292), targetY: 0.350),
        SkyworthCanvasPlacement(button: .left, side: .left, anchor: UnitPoint(x: 0.24, y: 0.378), targetY: 0.485),
        SkyworthCanvasPlacement(button: .back, side: .left, anchor: UnitPoint(x: 0.25, y: 0.545), targetY: 0.620),
        SkyworthCanvasPlacement(button: .home, side: .left, anchor: UnitPoint(x: 0.50, y: 0.545), targetY: 0.755),
        SkyworthCanvasPlacement(button: .multitask, side: .left, anchor: UnitPoint(x: 0.72, y: 0.655), targetY: 0.895),

        // Right column (7 buttons below voice status card)
        SkyworthCanvasPlacement(button: .right, side: .right, anchor: UnitPoint(x: 0.76, y: 0.378), targetY: 0.195),
        SkyworthCanvasPlacement(button: .ok, side: .right, anchor: UnitPoint(x: 0.50, y: 0.378), targetY: 0.318),
        SkyworthCanvasPlacement(button: .down, side: .right, anchor: UnitPoint(x: 0.50, y: 0.464), targetY: 0.440),
        SkyworthCanvasPlacement(button: .menu, side: .right, anchor: UnitPoint(x: 0.75, y: 0.545), targetY: 0.562),
        SkyworthCanvasPlacement(button: .volumeUp, side: .right, anchor: UnitPoint(x: 0.28, y: 0.648), targetY: 0.684),
        SkyworthCanvasPlacement(button: .volumeDown, side: .right, anchor: UnitPoint(x: 0.28, y: 0.742), targetY: 0.806),
        SkyworthCanvasPlacement(button: .quickDots, side: .right, anchor: UnitPoint(x: 0.72, y: 0.742), targetY: 0.925),
    ]

    static func remotePoint(for anchor: UnitPoint, canvasWidth: CGFloat) -> CGPoint {
        let origin = CGPoint(
            x: canvasWidth / 2 - remoteSize.width / 2,
            y: (canvasHeight - remoteSize.height) / 2
        )
        return CGPoint(
            x: origin.x + remoteSize.width * anchor.x,
            y: origin.y + remoteSize.height * anchor.y
        )
    }

    static func cardWidth(for canvasWidth: CGFloat) -> CGFloat {
        min(290, max(224, (canvasWidth - remoteSize.width - 104) / 2))
    }

    static func cardEdgePoint(
        side: RemoteMappingSide,
        targetY: CGFloat,
        canvasWidth: CGFloat,
        cardWidth: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: side == .left ? cardWidth : canvasWidth - cardWidth,
            y: canvasHeight * targetY
        )
    }
}

struct SkyworthButtonsMappingView: View {
    @EnvironmentObject private var localization: LocalizationStore
    @ObservedObject var model: BridgeAppModel
    let onOpenVoiceConnection: () -> Void

    @State private var selectedAppBundleID: String? = nil // nil = Global profile
    @State private var selectedButton: SkyworthButton?
    @State private var hoveredButton: SkyworthButton?

    private var voiceActive: Bool {
        model.activePhysicalVoiceControlSource == .skyworthRemote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar
            profileSwitcherBar
            canvasCard
        }
    }

    private var headerBar: some View {
        GlassPanel {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(model.skyworthRemoteConnected ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(localization.text(
                        model.skyworthRemoteConnected
                            ? "connection.skyworth.connected"
                            : "connection.skyworth.disconnected"
                    ))
                    .font(.system(size: 13, weight: .semibold))
                }

                Divider()
                    .frame(height: 16)

                HStack(spacing: 6) {
                    Text(localization.text("button_mapping.skyworth.last_button"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    if let last = model.lastSkyworthButton {
                        Text(last.displayName(using: localization))
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Text(localization.text("button_mapping.skyworth.waiting"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Button(localization.text("button_mapping.skyworth.open_voice")) {
                    onOpenVoiceConnection()
                }
                .compatibilityButtonStyle(.standard)

                Button(localization.text("skyworth.mapping.reset_defaults")) {
                    model.resetSkyworthButtonMappings()
                    selectedAppBundleID = nil
                }
                .compatibilityButtonStyle(.standard)
            }
        }
    }

    private var profileSwitcherBar: some View {
        GlassPanel {
            HStack(spacing: 8) {
                Text(localization.text("skyworth.profile.scope"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        profileChip(
                            title: localization.text("skyworth.profile.global"),
                            icon: nil,
                            isSelected: selectedAppBundleID == nil,
                            isActiveFrontmost: selectedAppBundleID == nil
                                && !model.skyworthMappingConfig.appProfiles.contains(where: { $0.bundleIdentifier == model.frontmostAppBundleID }),
                            onSelect: { selectedAppBundleID = nil },
                            onRemove: nil
                        )

                        ForEach(model.skyworthMappingConfig.appProfiles) { profile in
                            profileChip(
                                title: profile.displayName,
                                icon: appIcon(for: profile.bundleIdentifier),
                                isSelected: selectedAppBundleID == profile.bundleIdentifier,
                                isActiveFrontmost: model.frontmostAppBundleID == profile.bundleIdentifier,
                                onSelect: { selectedAppBundleID = profile.bundleIdentifier },
                                onRemove: {
                                    if selectedAppBundleID == profile.bundleIdentifier {
                                        selectedAppBundleID = nil
                                    }
                                    model.removeSkyworthAppProfile(bundleIdentifier: profile.bundleIdentifier)
                                }
                            )
                        }
                    }
                }

                Menu {
                    let candidates = runningAppCandidates()
                    if !candidates.isEmpty {
                        Section(localization.text("skyworth.profile.running_apps")) {
                            ForEach(candidates, id: \.bundleIdentifier) { app in
                                Button(app.displayName) {
                                    model.addSkyworthAppProfile(
                                        bundleIdentifier: app.bundleIdentifier,
                                        displayName: app.displayName
                                    )
                                    selectedAppBundleID = app.bundleIdentifier
                                }
                            }
                        }
                    }
                    Divider()
                    Button(localization.text("skyworth.profile.choose_app")) {
                        pickApplicationPanel()
                    }
                } label: {
                    Label(localization.text("skyworth.profile.add_app"), systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private func profileChip(
        title: String,
        icon: NSImage?,
        isSelected: Bool,
        isActiveFrontmost: Bool,
        onSelect: @escaping () -> Void,
        onRemove: (() -> Void)?
    ) -> some View {
        HStack(spacing: 5) {
            Button(action: onSelect) {
                HStack(spacing: 5) {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                    }
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    if isActiveFrontmost {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .buttonStyle(.plain)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.2)
        )
    }

    private func runningAppCandidates() -> [(bundleIdentifier: String, displayName: String)] {
        let existing = Set(model.skyworthMappingConfig.appProfiles.map(\.bundleIdentifier))
        let selfBundle = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier,
                      id != selfBundle,
                      !existing.contains(id),
                      let name = app.localizedName, !name.isEmpty
                else { return nil }
                return (id, name)
            }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private func appIcon(for bundleIdentifier: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func pickApplicationPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        model.addSkyworthAppProfile(bundleIdentifier: bundleID, displayName: name)
        selectedAppBundleID = bundleID
    }

    private var canvasCard: some View {
        GlassPanel {
            GeometryReader { proxy in
                let width = max(720, proxy.size.width)
                let cardW = SkyworthCanvasLayout.cardWidth(for: width)

                ZStack(alignment: .topLeading) {
                    connectorLines(canvasWidth: width, cardWidth: cardW)

                    SkyworthVectorRemoteView(
                        activeButtons: model.activeSkyworthButtons,
                        lastPressedButton: model.lastSkyworthButton,
                        selectedButton: selectedButton,
                        hoveredButton: hoveredButton,
                        voiceActive: voiceActive,
                        onSelect: { button in
                            selectedButton = button
                        },
                        onHover: { button in
                            hoveredButton = button
                        }
                    )
                    .frame(
                        width: SkyworthCanvasLayout.remoteSize.width,
                        height: SkyworthCanvasLayout.remoteSize.height
                    )
                    .position(
                        x: width / 2,
                        y: SkyworthCanvasLayout.canvasHeight / 2
                    )

                    voiceStatusCard
                        .frame(width: cardW)
                        .position(
                            x: width - cardW / 2,
                            y: SkyworthCanvasLayout.canvasHeight * SkyworthCanvasLayout.voiceTargetY
                        )

                    ForEach(SkyworthCanvasLayout.placements) { placement in
                        let isPressed = model.activeSkyworthButtons.contains(placement.button)
                        let isLast = model.lastSkyworthButton == placement.button
                        let isSelected = selectedButton == placement.button
                        let isHovered = hoveredButton == placement.button
                        let gestures = model.skyworthGestures(for: placement.button, appBundleID: selectedAppBundleID)
                        let isInherited = selectedAppBundleID.map {
                            !model.skyworthMappingConfig.hasOverride(for: placement.button, inApp: $0)
                        } ?? false

                        SkyworthMappingRowCard(
                            button: placement.button,
                            gestures: gestures,
                            isInherited: isInherited,
                            isPressed: isPressed,
                            isLast: isLast,
                            isSelected: isSelected,
                            isHovered: isHovered,
                            onTap: {
                                selectedButton = (selectedButton == placement.button) ? nil : placement.button
                            },
                            onHover: { hovering in
                                hoveredButton = hovering ? placement.button : (hoveredButton == placement.button ? nil : hoveredButton)
                            }
                        )
                        .frame(width: cardW)
                        .position(
                            x: placement.side == .left ? cardW / 2 : width - cardW / 2,
                            y: SkyworthCanvasLayout.canvasHeight * placement.targetY
                        )
                        .popover(
                            isPresented: Binding(
                                get: { selectedButton == placement.button },
                                set: { shown in
                                    if !shown, selectedButton == placement.button {
                                        selectedButton = nil
                                    }
                                }
                            ),
                            arrowEdge: placement.side == .left ? .trailing : .leading
                        ) {
                            SkyworthButtonBindingEditor(
                                button: placement.button,
                                gestures: gestures,
                                appBundleID: selectedAppBundleID,
                                hasAppOverride: selectedAppBundleID.map {
                                    model.skyworthMappingConfig.hasOverride(for: placement.button, inApp: $0)
                                } ?? false,
                                onSelect: { newBinding, gesture in
                                    model.setSkyworthButtonBinding(
                                        newBinding,
                                        for: placement.button,
                                        gesture: gesture,
                                        appBundleID: selectedAppBundleID
                                    )
                                },
                                onClearAppOverride: {
                                    if let appBundleID = selectedAppBundleID {
                                        model.clearSkyworthAppOverride(for: placement.button, appBundleID: appBundleID)
                                    }
                                },
                                onClose: {
                                    selectedButton = nil
                                }
                            )
                            .environmentObject(localization)
                        }
                    }
                }
            }
            .frame(height: SkyworthCanvasLayout.canvasHeight)
        }
    }

    private func connectorLines(canvasWidth: CGFloat, cardWidth: CGFloat) -> some View {
        Canvas { context, _ in
            let voiceStart = SkyworthCanvasLayout.remotePoint(
                for: SkyworthCanvasLayout.voiceAnchor,
                canvasWidth: canvasWidth
            )
            let voiceEnd = SkyworthCanvasLayout.cardEdgePoint(
                side: .right,
                targetY: SkyworthCanvasLayout.voiceTargetY,
                canvasWidth: canvasWidth,
                cardWidth: cardWidth
            )
            drawCurve(
                in: &context,
                from: voiceStart,
                to: voiceEnd,
                side: .right,
                highlighted: voiceActive,
                accent: voiceActive ? .orange : .secondary.opacity(0.45)
            )

            for placement in SkyworthCanvasLayout.placements {
                let start = SkyworthCanvasLayout.remotePoint(
                    for: placement.anchor,
                    canvasWidth: canvasWidth
                )
                let end = SkyworthCanvasLayout.cardEdgePoint(
                    side: placement.side,
                    targetY: placement.targetY,
                    canvasWidth: canvasWidth,
                    cardWidth: cardWidth
                )
                let highlighted = model.activeSkyworthButtons.contains(placement.button)
                    || selectedButton == placement.button
                    || hoveredButton == placement.button
                drawCurve(
                    in: &context,
                    from: start,
                    to: end,
                    side: placement.side,
                    highlighted: highlighted,
                    accent: highlighted ? .accentColor : .secondary.opacity(0.32)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func drawCurve(
        in context: inout GraphicsContext,
        from start: CGPoint,
        to cardEdge: CGPoint,
        side: RemoteMappingSide,
        highlighted: Bool,
        accent: Color
    ) {
        let tip = RemoteMappingLayout.arrowTip(cardEdge: cardEdge, side: side)
        let controls = RemoteMappingLayout.connectionControlPoints(start: start, end: tip, side: side)
        var path = Path()
        path.move(to: start)
        path.addCurve(to: tip, control1: controls.start, control2: controls.end)
        context.stroke(
            path,
            with: .color(accent),
            style: StrokeStyle(lineWidth: highlighted ? 2.0 : 1.1, lineCap: .round)
        )
        let dotRect = CGRect(x: start.x - 2.5, y: start.y - 2.5, width: 5, height: 5)
        context.fill(Path(ellipseIn: dotRect), with: .color(accent))
    }

    private var voiceStatusCard: some View {
        HStack(spacing: 8) {
            Image(systemName: voiceActive ? "mic.fill" : "mic")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(voiceActive ? Color.orange : Color.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(localization.text("skyworth.voice_card.title"))
                    .font(.system(size: 12, weight: .semibold))
                Text(localization.text(voiceActive ? "connection.status.voice_streaming" : "skyworth.voice_card.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(voiceActive ? Color.orange : .secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text("0xEA/EB")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(voiceActive ? Color.orange.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(voiceActive ? Color.orange : Color.primary.opacity(0.1), lineWidth: voiceActive ? 1.5 : 1)
        )
    }
}

private struct SkyworthMappingRowCard: View {
    @EnvironmentObject private var localization: LocalizationStore
    let button: SkyworthButton
    let gestures: SkyworthButtonGestures
    let isInherited: Bool
    let isPressed: Bool
    let isLast: Bool
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void
    let onHover: (Bool) -> Void

    private var isEmphasized: Bool {
        isPressed || isSelected || isHovered
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Image(systemName: button.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isEmphasized ? Color.accentColor : .secondary)
                        .frame(width: 16)

                    Text(button.displayName(using: localization))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isInherited ? .secondary : .primary)
                        .lineLimit(1)

                    if isInherited {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 4)

                    Text(gestures.singleClick.displayName(using: localization))
                        .font(.system(size: 11, weight: gestures.singleClick.isCustom ? .semibold : .regular))
                        .foregroundStyle(
                            gestures.singleClick.isCustom
                                ? (isInherited ? Color.accentColor.opacity(0.7) : Color.accentColor)
                                : .secondary
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(gestures.singleClick.isCustom ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.06))
                        )
                        .lineLimit(1)
                }

                if gestures.hasDoubleClick || gestures.hasLongPress {
                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        if let dbl = gestures.doubleClick, dbl.isCustom {
                            gestureMiniChip(
                                prefix: localization.text("skyworth.gesture.double_short"),
                                value: dbl.displayName(using: localization)
                            )
                        }
                        if let lng = gestures.longPress, lng.isCustom {
                            gestureMiniChip(
                                prefix: localization.text("skyworth.gesture.long_short"),
                                value: lng.displayName(using: localization)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, gestures.hasDoubleClick || gestures.hasLongPress ? 5 : 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isPressed
                            ? Color.accentColor.opacity(0.18)
                            : Color(nsColor: .controlBackgroundColor).opacity(isEmphasized ? 0.95 : 0.72)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isPressed || isSelected
                            ? Color.accentColor
                            : (isLast ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.09)),
                        lineWidth: isPressed || isSelected ? 1.5 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
    }

    private func gestureMiniChip(prefix: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(prefix)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(.quaternary.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct SkyworthVectorRemoteView: View {
    @Environment(\.colorScheme) private var colorScheme
    let activeButtons: Set<SkyworthButton>
    let lastPressedButton: SkyworthButton?
    let selectedButton: SkyworthButton?
    let hoveredButton: SkyworthButton?
    let voiceActive: Bool
    let onSelect: (SkyworthButton) -> Void
    let onHover: (SkyworthButton?) -> Void

    private var bodyGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(white: 0.22), Color(white: 0.13)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Color(white: 0.26), Color(white: 0.17)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(bodyGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                )
                .shadow(color: .black.opacity(0.28), radius: 14, y: 8)

            VStack(spacing: 0) {
                HStack {
                    remoteCircleButton(.power, diameter: 34, tint: .red) {
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    remoteCircleButton(.input, diameter: 34) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 26)

                ZStack {
                    Circle()
                        .fill(voiceActive ? Color.orange : Color(white: 0.28))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(voiceActive ? Color.orange.opacity(0.9) : Color.white.opacity(0.2), lineWidth: voiceActive ? 2.5 : 1)
                        )
                        .shadow(color: voiceActive ? Color.orange.opacity(0.6) : .clear, radius: 8)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 14)

                ZStack {
                    Circle()
                        .fill(Color(white: 0.24))
                        .frame(width: 138, height: 138)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1.2)
                        )

                    remoteCircleButton(.up, diameter: 34, transparent: true) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .offset(y: -47)

                    remoteCircleButton(.down, diameter: 34, transparent: true) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .offset(y: 47)

                    remoteCircleButton(.left, diameter: 34, transparent: true) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .offset(x: -47)

                    remoteCircleButton(.right, diameter: 34, transparent: true) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .offset(x: 47)

                    remoteCircleButton(.ok, diameter: 54) {
                        Text("OK")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 18)

                HStack(spacing: 16) {
                    remoteCircleButton(.back, diameter: 36) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    remoteCircleButton(.home, diameter: 36) {
                        Image(systemName: "house")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    remoteCircleButton(.menu, diameter: 36) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.top, 20)

                HStack(spacing: 34) {
                    VStack(spacing: 0) {
                        remoteRockerHalf(.volumeUp, top: true) {
                            Text("+")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 24, height: 1)
                        remoteRockerHalf(.volumeDown, top: false) {
                            Text("−")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 44, height: 96)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.25))
                            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    )

                    VStack(spacing: 18) {
                        remoteCircleButton(.multitask, diameter: 38) {
                            Image(systemName: "square.on.square")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        remoteCircleButton(.quickDots, diameter: 38) {
                            HStack(spacing: 3.5) {
                                Circle().fill(Color.red).frame(width: 5, height: 5)
                                Circle().fill(Color.green).frame(width: 5, height: 5)
                                Circle().fill(Color.blue).frame(width: 5, height: 5)
                            }
                        }
                    }
                }
                .padding(.top, 20)

                Spacer()

                Text("SKYWORTH")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.bottom, 20)
            }
        }
    }

    private func isHighlighted(_ button: SkyworthButton) -> Bool {
        activeButtons.contains(button) || selectedButton == button || hoveredButton == button
    }

    private func remoteCircleButton<Content: View>(
        _ button: SkyworthButton,
        diameter: CGFloat,
        tint: Color? = nil,
        transparent: Bool = false,
        @ViewBuilder label: () -> Content
    ) -> some View {
        let pressed = activeButtons.contains(button)
        let active = isHighlighted(button)
        let isLast = lastPressedButton == button

        return Button {
            onSelect(button)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        pressed
                            ? Color.accentColor
                            : (transparent ? Color.clear : (tint ?? Color(white: 0.27)))
                    )
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .stroke(
                                active
                                    ? Color.accentColor
                                    : (isLast ? Color.accentColor.opacity(0.55) : Color.white.opacity(transparent ? 0 : 0.14)),
                                lineWidth: active ? 2.2 : 1
                            )
                    )
                    .shadow(color: pressed ? Color.accentColor.opacity(0.75) : .clear, radius: 8)
                label()
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering ? button : (hoveredButton == button ? nil : hoveredButton))
        }
    }

    private func remoteRockerHalf<Content: View>(
        _ button: SkyworthButton,
        top: Bool,
        @ViewBuilder label: () -> Content
    ) -> some View {
        let pressed = activeButtons.contains(button)
        let active = isHighlighted(button)

        return Button {
            onSelect(button)
        } label: {
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: top ? 22 : 0,
                    bottomLeadingRadius: top ? 0 : 22,
                    bottomTrailingRadius: top ? 0 : 22,
                    topTrailingRadius: top ? 22 : 0
                )
                .fill(pressed ? Color.accentColor : (active ? Color.accentColor.opacity(0.35) : Color.clear))
                label()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering ? button : (hoveredButton == button ? nil : hoveredButton))
        }
    }
}

private struct SkyworthButtonBindingEditor: View {
    @EnvironmentObject private var localization: LocalizationStore
    let button: SkyworthButton
    let gestures: SkyworthButtonGestures
    let appBundleID: String?
    let hasAppOverride: Bool
    let onSelect: (SkyworthButtonBinding?, SkyworthGesture) -> Void
    let onClearAppOverride: () -> Void
    let onClose: () -> Void

    @State private var selectedGesture: SkyworthGesture = .singleClick
    @State private var isRecordingShortcut = false
    @State private var keyMonitor: Any?

    private var activeBinding: SkyworthButtonBinding? {
        gestures.binding(for: selectedGesture)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Image(systemName: button.symbolName)
                    .foregroundStyle(Color.accentColor)
                Text(button.displayName(using: localization))
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if appBundleID != nil, hasAppOverride {
                    Button(localization.text("skyworth.profile.inherit_global")) {
                        stopRecording()
                        onClearAppOverride()
                        onClose()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.link)
                } else {
                    Text(button.hidCodeLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Picker("", selection: $selectedGesture) {
                ForEach(SkyworthGesture.allCases) { gesture in
                    Text(gesture.displayName(using: localization)).tag(gesture)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: selectedGesture) { _, _ in
                stopRecording()
            }

            // Native / Unset option
            Button {
                stopRecording()
                onSelect(selectedGesture == .singleClick ? .native : nil, selectedGesture)
            } label: {
                let isSelectedNone = (selectedGesture == .singleClick && activeBinding == .native)
                    || (selectedGesture != .singleClick && activeBinding == nil)
                HStack {
                    Image(systemName: isSelectedNone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelectedNone ? Color.accentColor : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.text(
                            selectedGesture == .singleClick
                                ? "skyworth.binding.native"
                                : "skyworth.gesture.unset"
                        ))
                        .font(.system(size: 12, weight: .semibold))
                        Text(localization.text(
                            selectedGesture == .singleClick
                                ? "skyworth.binding.native_hint"
                                : "skyworth.gesture.unset_hint"
                        ))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            // Custom Mac shortcut recorder
            VStack(alignment: .leading, spacing: 6) {
                Text(localization.text("skyworth.editor.custom_shortcut"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Button {
                    if isRecordingShortcut {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isRecordingShortcut ? "record.circle" : "keyboard")
                            .foregroundStyle(isRecordingShortcut ? Color.red : Color.accentColor)
                        if isRecordingShortcut {
                            Text(localization.text("skyworth.editor.press_shortcut"))
                        } else if case .customShortcut(let shortcut) = activeBinding {
                            Text(shortcut.displayName(using: localization))
                        } else {
                            Text(localization.text("skyworth.editor.record_shortcut"))
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isRecordingShortcut ? Color.red.opacity(0.12) : Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(SkyworthButtonMappingStore.presetGroups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(localization.text(group.titleKey))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary)
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                                spacing: 6
                            ) {
                                ForEach(group.actions) { action in
                                    let selected = activeBinding == .action(action)
                                    Button {
                                        stopRecording()
                                        onSelect(.action(action), selectedGesture)
                                    } label: {
                                        Text(action.displayName(using: localization))
                                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                            .foregroundStyle(selected ? .white : .primary)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 5)
                                            .padding(.horizontal, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(selected ? Color.accentColor : Color.primary.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(14)
        .frame(width: 324)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecordingShortcut = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                stopRecording()
                return nil
            }
            let shortcut = CustomKeyboardShortcut(event: event)
            stopRecording()
            onSelect(.customShortcut(shortcut), selectedGesture)
            return nil
        }
    }

    private func stopRecording() {
        isRecordingShortcut = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
