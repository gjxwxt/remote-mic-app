import Foundation
import IOKit.hid

/// Read-only HID voice transport for the observed YK-8E00 (not older RC86).
/// Ordinary keys retain their system behavior; no device seizure or writes.
final class SkyworthVoiceMonitor {
    static let vendorID = 0x0094
    static let productID = 0x0013
    // Physical voice trigger press (0xEA) and release (0xEB) arrive on report 1.
    // Keep a 0.50s idle fallback so normal 0xEB (~270-290ms after last audio)
    // always closes cleanly while BLE drops still recover automatically.
    static let idleTimeout: TimeInterval = 0.50
    static let voicePressUsage: UInt8 = 0xEA
    static let voiceReleaseUsage: UInt8 = 0xEB
    var onConnectionChange: ((Bool) -> Void)?
    var onButtonPress: ((RemoteButton) -> Void)?
    var onSkyworthButtonPress: ((SkyworthButton) -> Void)?
    var onSkyworthButtonRelease: ((SkyworthButton) -> Void)?
    var onSkyworthHeldButtonsChange: ((Set<SkyworthButton>) -> Void)?
    var onStart: (() -> Bool)?
    var onAudio: (([Int16]) -> Void)?
    var onStop: ((String) -> Void)?
    var log: (String) -> Void = { AppLogger.shared.write($0) }

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
    private var heldButtons: [UInt32: Set<RemoteButton>] = [:]
    private var heldSkyworthButtons: [UInt32: Set<SkyworthButton>] = [:]
    private var decoder = SkyworthSBCDecoder()
    private var idleWork: DispatchWorkItem?
    private var generation: UInt64 = 0
    private var idleRevision: UInt64 = 0
    private var active = false
    private var rejected = false
    private var packets = 0
    private var samples = 0
    private var startedAt: TimeInterval = 0
    private var triggerDownAt: TimeInterval?
    private var candidates: [UInt: IOHIDDevice] = [:]

    deinit {
        stop(reason: "adapter_released")
        buffer.deallocate()
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard manager == nil else { return }
        guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else {
            return
        }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        self.manager = manager
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: Self.vendorID, kIOHIDProductIDKey: Self.productID,
        ] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard let context, result == kIOReturnSuccess else { return }
            Unmanaged<SkyworthVoiceMonitor>.fromOpaque(context).takeUnretainedValue().matched(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<SkyworthVoiceMonitor>.fromOpaque(context).takeUnretainedValue().removed(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, 0)
        guard result == kIOReturnSuccess else {
            log("SKYWORTH HID phase=failed reason=manager_open error_code=\(result)")
            stop(reason: "manager_open")
            return
        }
        log("SKYWORTH HID phase=started model_family=yk8e00 release_observation=physical_eb")
    }

    func stop(reason: String) {
        dispatchPrecondition(condition: .onQueue(.main))
        closeStream(reason: reason)
        detachDevice()
        candidates.removeAll()
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, 0)
        }
        manager = nil
    }

    private func matched(_ candidate: IOHIDDevice) {
        guard manager != nil else { return }
        candidates[Self.key(candidate)] = candidate
        guard candidates.count == 1 else {
            closeStream(reason: "ambiguous_device")
            detachDevice()
            log("SKYWORTH HID phase=rejected reason=ambiguous_device")
            return
        }
        attach(candidate)
    }

    private func removed(_ candidate: IOHIDDevice) {
        candidates.removeValue(forKey: Self.key(candidate))
        if device.map(Self.key) == Self.key(candidate) {
            closeStream(reason: "device_disconnected")
            detachDevice()
        }
        if candidates.count == 1, let remaining = candidates.values.first { attach(remaining) }
    }

    private func attach(_ candidate: IOHIDDevice) {
        guard device == nil else { return }
        let result = IOHIDDeviceOpen(candidate, 0)
        guard result == kIOReturnSuccess else {
            log("SKYWORTH HID phase=failed reason=device_open error_code=\(result)")
            return
        }
        device = candidate
        IOHIDDeviceRegisterInputReportCallback(candidate, buffer, 512, { context, result, sender, _, id, bytes, count in
            guard let context else { return }
            let owner = Unmanaged<SkyworthVoiceMonitor>.fromOpaque(context).takeUnretainedValue()
            guard let current = owner.device,
                  sender == Unmanaged.passUnretained(current).toOpaque() else { return }
            guard result == kIOReturnSuccess else {
                owner.interrupt(reason: "report_error")
                return
            }
            guard count > 0, count <= 512 else { return }
            switch id {
            case 0x5A:
                owner.receive(reportID: id, data: Data(bytes: bytes, count: count))
            case 1, 2:
                owner.receiveButtons(reportID: id, bytes: UnsafeBufferPointer(start: bytes, count: count))
            default:
                owner.logUnknownReport(reportID: id, bytes: bytes, count: count)
            }
        }, Unmanaged.passUnretained(self).toOpaque())
        log("SKYWORTH HID phase=ready model_family=yk8e00")
        onConnectionChange?(true)
    }

    private func detachDevice() {
        if let device {
            IOHIDDeviceRegisterInputReportCallback(
                device, buffer, 512, nil, Unmanaged.passUnretained(self).toOpaque()
            )
            IOHIDDeviceClose(device, 0)
            self.device = nil
            onConnectionChange?(false)
        }
        heldButtons.removeAll()
        if !heldSkyworthButtons.isEmpty {
            heldSkyworthButtons.removeAll()
            onSkyworthHeldButtonsChange?([])
        }
        decoder.reset()
    }

    // Hardware-verified YK-8E00 (0094:0013) keyboard & consumer controls.
    // Report 1 carries ordinary keys + physical voice press (0xEA) / release (0xEB).
    func receiveButtons(reportID: UInt32, bytes: UnsafeBufferPointer<UInt8>) {
        guard bytes.first == UInt8(exactly: reportID) else { return }
        let skyworthButtons: Set<SkyworthButton>
        let legacyButtons: Set<RemoteButton>
        switch (reportID, bytes.count) {
        case (1, 9):
            let skyworthKeys: [UInt8: SkyworthButton] = [
                0x28: .ok, 0x96: .ok,
                0x29: .back, 0x2A: .back, 0xF1: .back,
                0x4F: .right, 0x50: .left, 0x51: .down, 0x52: .up,
                0x80: .volumeUp, 0x81: .volumeDown,
                0x65: .menu, 0x66: .power,
                0xA0: .input, 0xC9: .multitask, 0xCA: .quickDots,
            ]
            // Report ID, modifier mask and reserved byte precede six key usages.
            let usages = bytes.dropFirst(3)
            guard !usages.contains(where: { (1...3).contains($0) }) else { return }
            if usages.contains(Self.voicePressUsage) {
                handlePhysicalVoicePress()
            }
            if usages.contains(Self.voiceReleaseUsage) {
                handlePhysicalVoiceRelease()
            }
            skyworthButtons = Set(usages.compactMap { skyworthKeys[$0] })
            legacyButtons = Set(skyworthButtons.compactMap(\.legacyRemoteButton))
        case (2, 4):
            // Consumer usages in descriptor order: play/pause, mute,
            // volume up/down, AC Home, then AC Back.
            let legacyBindings: [(Int, RemoteButton)] = [
                (3, .playPause), (4, .mute), (7, .volumeUp), (8, .volumeDown),
                (18, .home), (19, .back),
            ]
            legacyButtons = Set(legacyBindings.compactMap { bit, button in
                bytes[1 + bit / 8] & (1 << (bit % 8)) != 0 ? button : nil
            })
            let skyworthBindings: [(Int, SkyworthButton)] = [
                (7, .volumeUp), (8, .volumeDown),
                (18, .home), (19, .back),
            ]
            skyworthButtons = Set(skyworthBindings.compactMap { bit, button in
                bytes[1 + bit / 8] & (1 << (bit % 8)) != 0 ? button : nil
            })
        default:
            return
        }
        let previousForReport = heldSkyworthButtons[reportID, default: []]
        let newlyPressedSkyworth = skyworthButtons.subtracting(previousForReport)
        let newlyReleasedSkyworth = previousForReport.subtracting(skyworthButtons)
        let previousCombined = heldSkyworthButtons.values.reduce(into: Set<SkyworthButton>()) { $0.formUnion($1) }
        heldSkyworthButtons[reportID] = skyworthButtons
        let currentCombined = heldSkyworthButtons.values.reduce(into: Set<SkyworthButton>()) { $0.formUnion($1) }
        if previousCombined != currentCombined {
            onSkyworthHeldButtonsChange?(currentCombined)
        }
        for button in newlyPressedSkyworth.sorted(by: { $0.rawValue < $1.rawValue }) {
            onSkyworthButtonPress?(button)
        }
        for button in newlyReleasedSkyworth.sorted(by: { $0.rawValue < $1.rawValue }) {
            onSkyworthButtonRelease?(button)
        }

        let newlyPressedLegacy = legacyButtons.subtracting(heldButtons[reportID, default: []])
        heldButtons[reportID] = legacyButtons
        for button in newlyPressedLegacy.sorted(by: { $0.rawValue < $1.rawValue }) {
            onButtonPress?(button)
        }
    }

    private func handlePhysicalVoicePress() {
        if active {
            closeStream(reason: "retriggered")
        }
        rejected = false
        decoder.reset()
        generation &+= 1
        let now = ProcessInfo.processInfo.systemUptime
        startedAt = now
        triggerDownAt = now
        packets = 0
        samples = 0
        guard onStart?() == true else {
            rejected = true
            triggerDownAt = nil
            scheduleIdle()
            log("SKYWORTH VOICE generation=\(generation) phase=rejected reason=host_unavailable trigger_observation=physical_ea")
            return
        }
        active = true
        scheduleIdle()
        log("SKYWORTH VOICE generation=\(generation) phase=started trigger_observation=physical_ea")
    }

    private func handlePhysicalVoiceRelease() {
        if active {
            closeStream(reason: "button_release")
        } else if rejected {
            idleWork?.cancel()
            idleWork = nil
            idleRevision &+= 1
            rejected = false
            triggerDownAt = nil
            decoder.reset()
        }
    }

    func interrupt(reason: String) {
        guard active else { return }
        closeStream(reason: reason)
        rejected = true
        scheduleIdle()
    }

    func receive(reportID: UInt32, data: Data) {
        if rejected {
            scheduleIdle()
            return
        }
        guard let decoded = decoder.decode(reportID: reportID, data: data) else {
            log("SKYWORTH VOICE generation=\(generation) phase=failed reason=invalid_sbc len=\(data.count) diagnostic_boundary=profile_or_crc")
            closeStream(reason: "invalid_sbc")
            rejected = true
            scheduleIdle()
            return
        }
        scheduleIdle()
        if !active {
            generation &+= 1
            startedAt = ProcessInfo.processInfo.systemUptime
            triggerDownAt = nil
            packets = 0
            samples = 0
            guard onStart?() == true else {
                rejected = true
                decoder.reset()
                log("SKYWORTH VOICE generation=\(generation) phase=rejected reason=host_unavailable")
                return
            }
            active = true
            log("SKYWORTH VOICE generation=\(generation) phase=started trigger_observation=first_audio trigger_down_to_first_pcm_ms=unknown")
        } else if packets == 0, let downAt = triggerDownAt {
            let leadMs = max(0, Int((ProcessInfo.processInfo.systemUptime - downAt) * 1000))
            log("SKYWORTH VOICE generation=\(generation) phase=first_audio trigger_down_to_first_pcm_ms=\(leadMs)")
        }
        packets += 1
        samples += decoded.count
        // Same bounded gain as the successful replay test; no dynamic lookahead.
        onAudio?(decoded.map { Int16(min(18_022, max(-18_022, Int($0) * 8))) })
    }

    private func scheduleIdle() {
        idleWork?.cancel()
        idleRevision &+= 1
        let revision = idleRevision
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.idleRevision == revision else { return }
            self.closeStream(reason: "release_unobserved")
        }
        idleWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleTimeout, execute: item)
    }

    private func closeStream(reason: String) {
        idleWork?.cancel()
        idleWork = nil
        idleRevision &+= 1
        if active {
            active = false
            let elapsed = max(0, Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1000))
            let isPhysicalRelease = reason == "button_release"
            let completion = isPhysicalRelease ? "normal" : "forced"
            let releaseObservation = isPhysicalRelease ? "physical_eb" : "unknown"
            log("SKYWORTH VOICE generation=\(generation) phase=stopping completion=\(completion) reason=\(reason) packets=\(packets) decoded_samples=\(samples) elapsed_ms=\(elapsed) release_observation=\(releaseObservation)")
            onStop?(reason)
        }
        rejected = false
        triggerDownAt = nil
        decoder.reset()
    }

    private func logUnknownReport(reportID: UInt32, bytes: UnsafePointer<UInt8>, count: Int) {
        let shown = min(count, 32)
        let hex = UnsafeBufferPointer(start: bytes, count: shown)
            .map { String(format: "%02x", $0) }
            .joined(separator: " ")
        log("SKYWORTH HID_REPORT id=\(String(format: "0x%02x", reportID)) len=\(count) hex=\(hex)")
    }

    private static func key(_ device: IOHIDDevice) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }
}
