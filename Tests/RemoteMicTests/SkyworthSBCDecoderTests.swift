import Foundation
import Testing
@testable import RemoteMic

@Suite("YK-8E00 ordinary SBC")
struct SkyworthSBCDecoderTests {
    // Generated 440 Hz sine, FFmpeg SBC 60 kbit/s, 16 kHz mono; no user speech.
    private let encoded = Data(base64Encoded: "nDEaabdlRUR+7ttgO7bYUQ22LEKNs31BewzA5hENtAO7bWzu2327ttvu7bR7u20a7ttuO7bfju21w7ttnDEaqLAAAAAAhVVXVRVfJ5VXNjlVKpFVRJoVWsVFV/i5VYLyVUC4VVTixVeplVXZslVNzJVQsAVWc8VVnDEaqLAAAAD/1VVkvJVQdBFU/yFV4KlVeRuVVE9lVBW1VY0ZVX/dVVoqZVQ2BVUybFV1WlVe2SVVTplVnDEaqLAAAAABzFVfQhVf0ZVWxzlVFZVVSZIVXIyFV9PpVWMJVUAJVVbQhVfi5lXAMlVH1FVRuMVW7BFV")!
    private let reference = Data(base64Encoded: "AAAAAAAAAAAAAAAAAAAAAAAA////////AAAAAAAAAAAAAAAAAAAAAAAAAAD//////////wAAAQABAAIAAgACAAMAAwAAAP7/+//5//b/9v/4//n/+v/2//H/7//x/wIAEgAbACEAIgAmACkAGgAKAPv//P8HAPz/CwAOAAcALgAWAAcAIgAJAAQA/v/U/w4A9P8xAL8CjwXaB0AKGgzHDegOyg8fEM8POA8KDpIMigo/CNkFJwNyAKz99/pf+BH2HPSA8kXxbPAN8CfwwPDL8UPzH/VN9775XPwU/9IBhAQSB20JggtADZoOhw/9D/gPeA+GDiQNXQs/CdwGRASKAcX+C/xu+QX33/QQ86PxpfAd8ArwcvBN8ZfySPRQ9qT4Mvvk/agAaAMQBosIxQqsDDAORw/nDw0QtA/jDqAN8QvnCZYHCwVcAp7/4vxA+sv3kvWn8xny9PBA8APwP/D08Bzyq/Oa9df3VPr9/Lz/fgIuBbUHAAoADKMN3w6pD/sP0w80DyEOowzECpMIIAZ9A78A/v1M+734ZvZY9KPyU/F28AvwG/Ck8KLxD/Pf9AP3bvkI/MD+ggE3BM4GMQlOCxQNeA5uD+0P8g9/D5UOOw16C2cJCQd3BMIBAP9F/Kf5OPcN9TXzwPG38CHwB/Bl8D3xgfIu9DP2hPgO+7/9gAA+A+MFXAiTCnoMBA4iD8sP+w+1D/YOxQ0pDDMK7QdqBb0C//8//ZX6FPjQ9djzPvIM8U3wBPA08N7w+vGD82v1p/ce+sP8gP9BAvIEfAfNCdMLgA3GDpsP+Q/eD0kPPw7IDPMKyQhbBrwDAQE+/or7+Pic9oT0xfJr8YLwEPAW8JfwifHr8rH0zPYv+cX7ff5CAfoDlgb+CCEL8QxcDlsP4w/1D40Prw5fDaoLmwlCB7MEAQI//4T84vlv9zz1XfPf8cvwLfAF8FfwIPFc8gH0AfZL+NP6gf1BAAADpgUkCGIKUgzkDQwPwA/+D8IPDA/iDVIMYwokCKgFAANCAID90vpL+AD2AfRd8iHxV/AF8C3wzPDf8V3zPPVt9+D5gvxB/wMCtQREB5oJqQtdDa4Oiw/1D+YPXQ9dDvIMIgv9CJMG+ANBAX7+yPsy+dD2s/Tt8onxk/AT8A7wgvBt8cbyh/Sa9vf4ifs9/gABuwNaBskI9ArMDEAOSQ/fD/oPnA/EDoAN0wvNCXwH8gRDAoD/wfwd+qT3bvWF8/7x3/A28AbwTPAK8Tzy1vPO9RP4lvpD/QEAwQJrBeoHMQooDMMN9A60D/0Pyw8hDwYOfgyWCloI4wU9A4EAv/0P+4X4M/Ys9H/yOvFl8AbwI/C38MHxOfMO9Tf3pflD/P/+wQF2BA==")!

    private func report(_ bytes: Data) -> Data { Data([0x5A]) + bytes }

    @Test func decodesConsecutiveReportsAgainstIndependentFFmpegReference() throws {
        var decoder = SkyworthSBCDecoder()
        let firstDecoded = decoder.decode(reportID: 0x5A, data: report(encoded.prefix(120)))
        let a = try #require(firstDecoded)
        let secondDecoded = decoder.decode(reportID: 0x5A, data: report(encoded.suffix(120)))
        let b = try #require(secondDecoded)
        let actual = a + b
        let bytes = Array(reference)
        let expected = stride(from: 0, to: bytes.count, by: 2).map {
            Int16(bitPattern: UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8)
        }
        #expect(actual.count == 512)
        #expect(actual.count == expected.count)
        #expect(zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 2 })
    }

    @Test func rejectsOtherLayoutsAndCRCWithoutAdvancingSynthesisState() throws {
        var decoder = SkyworthSBCDecoder()
        let first = report(encoded.prefix(120))
        let second = report(encoded.suffix(120))
        let rejected0 = decoder.decode(reportID: 31, data: first)
        #expect(rejected0 == nil)
        let rejected1 = decoder.decode(reportID: 0x5A, data: first.dropLast())
        #expect(rejected1 == nil)
        let rejected2 = decoder.decode(reportID: 0x5A, data: Data([1]) + first.dropFirst())
        #expect(rejected2 == nil)
        var crcFailure = first
        crcFailure[64] ^= 1 // Second frame CRC: first-frame state must not commit.
        let rejected3 = decoder.decode(reportID: 0x5A, data: crcFailure)
        #expect(rejected3 == nil)
        var fresh = SkyworthSBCDecoder()
        let actual0 = decoder.decode(reportID: 0x5A, data: first)
        let expected0 = fresh.decode(reportID: 0x5A, data: first)
        #expect(actual0 == expected0)
        let actual1 = decoder.decode(reportID: 0x5A, data: second)
        let expected1 = fresh.decode(reportID: 0x5A, data: second)
        #expect(actual1 == expected1)
        decoder.reset()
        fresh.reset()
        let actual2 = decoder.decode(reportID: 0x5A, data: first)
        let expected2 = fresh.decode(reportID: 0x5A, data: first)
        #expect(actual2 == expected2)
    }
    @Test @MainActor func transportKeepsReportsOrderedAndClosesOnceOnInterruption() {
        let monitor = SkyworthVoiceMonitor()
        var starts = 0
        var audio: [Int16] = []
        var stops: [String] = []
        var logs: [String] = []
        monitor.onStart = { starts += 1; return true }
        monitor.onAudio = { audio += $0 }
        monitor.onStop = { stops.append($0) }
        monitor.log = { logs.append($0) }
        monitor.receive(reportID: 0x5A, data: report(encoded.prefix(120)))
        monitor.receive(reportID: 0x5A, data: report(encoded.suffix(120)))
        #expect(starts == 1)
        #expect(audio.count == 512)
        monitor.stop(reason: "device_disconnected")
        monitor.stop(reason: "adapter_stopped")
        #expect(stops == ["device_disconnected"])
        #expect(logs.contains { $0.contains("completion=forced") })
        #expect(logs.contains { $0.contains("release_observation=unknown") })
    }

    @Test @MainActor func rejectedStartCannotRestartOnEveryAudioPacket() {
        let monitor = SkyworthVoiceMonitor()
        var starts = 0
        var batches = 0
        monitor.onStart = { starts += 1; return false }
        monitor.onAudio = { _ in batches += 1 }
        monitor.log = { _ in }
        monitor.receive(reportID: 0x5A, data: report(encoded.prefix(120)))
        monitor.receive(reportID: 0x5A, data: report(encoded.suffix(120)))
        #expect(starts == 1)
        #expect(batches == 0)
        monitor.stop(reason: "test_end")
    }

    @Test @MainActor func standardButtonReportsObserveOnlyFreshPresses() {
        let monitor = SkyworthVoiceMonitor()
        var buttons: [RemoteButton] = []
        monitor.onButtonPress = { buttons.append($0) }
        let arrow: [UInt8] = [1, 0, 0, 0x4F, 0, 0, 0, 0, 0]
        let released: [UInt8] = [1, 0, 0, 0, 0, 0, 0, 0, 0]
        let consumer: [UInt8] = [2, 0x80, 0, 0]
        arrow.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        arrow.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        consumer.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 2, bytes: $0) }
        released.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        arrow.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        consumer.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 2, bytes: $0) }
        #expect(buttons == [.right, .volumeUp, .right])
    }

    @Test @MainActor func keyboardHeaderCannotBecomeAButtonOrRolloverError() {
        let monitor = SkyworthVoiceMonitor()
        var buttons: [RemoteButton] = []
        monitor.onButtonPress = { buttons.append($0) }
        let modifierOnly: [UInt8] = [1, 0x28, 0, 0, 0, 0, 0, 0, 0]
        let modifiedArrow: [UInt8] = [1, 1, 0, 0x4F, 0, 0, 0, 0, 0]
        modifierOnly.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        #expect(buttons.isEmpty)
        modifiedArrow.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        #expect(buttons == [.right])
    }

    @Test @MainActor func interruptionRejectsRemainingPacketsUntilStreamEnds() {
        let monitor = SkyworthVoiceMonitor()
        monitor.log = { _ in }
        var starts = 0
        var batches = 0
        var stops: [String] = []
        monitor.onStart = { starts += 1; return true }
        monitor.onAudio = { _ in batches += 1 }
        monitor.onStop = { stops.append($0) }
        monitor.receive(reportID: 0x5A, data: report(encoded.prefix(120)))
        monitor.interrupt(reason: "target_interrupted")
        monitor.receive(reportID: 0x5A, data: report(encoded.suffix(120)))
        #expect(starts == 1)
        #expect(batches == 1)
        #expect(stops == ["target_interrupted"])
        monitor.stop(reason: "device_disconnected")
        #expect(stops == ["target_interrupted"])
    }

    @Test @MainActor func gapEndsOneSessionAndAllowsNextBurst() async throws {
        let monitor = SkyworthVoiceMonitor()
        monitor.log = { _ in }
        var starts = 0
        var stops: [String] = []
        monitor.onStart = { starts += 1; return true }
        monitor.onStop = { stops.append($0) }
        monitor.receive(reportID: 0x5A, data: report(encoded.prefix(120)))
        try await Task.sleep(for: .milliseconds(650))
        #expect(stops == ["release_unobserved"])
        monitor.receive(reportID: 0x5A, data: report(encoded.prefix(120)))
        #expect(starts == 2)
        monitor.stop(reason: "test_end")
        #expect(stops == ["release_unobserved", "test_end"])
    }

    @Test @MainActor func physicalVoiceTriggerStartsBeforeAudioAndClosesNormallyOnRelease() {
        let monitor = SkyworthVoiceMonitor()
        var starts = 0
        var audioSamples = 0
        var stops: [String] = []
        var buttons: [RemoteButton] = []
        var logs: [String] = []
        monitor.onStart = { starts += 1; return true }
        monitor.onAudio = { audioSamples += $0.count }
        monitor.onStop = { stops.append($0) }
        monitor.onButtonPress = { buttons.append($0) }
        monitor.log = { logs.append($0) }

        let press: [UInt8] = [1, 0, 0, 0xEA, 0, 0, 0, 0, 0]
        let empty: [UInt8] = [1, 0, 0, 0x00, 0, 0, 0, 0, 0]
        let release: [UInt8] = [1, 0, 0, 0xEB, 0, 0, 0, 0, 0]

        press.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        empty.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        #expect(starts == 1)
        #expect(buttons.isEmpty)

        monitor.receive(reportID: 0x5A, data: report(encoded.prefix(120)))
        #expect(starts == 1)
        #expect(audioSamples == 256)

        release.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        release.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        #expect(stops == ["button_release"])
        #expect(buttons.isEmpty)
        #expect(logs.contains { $0.contains("trigger_observation=physical_ea") })
        #expect(logs.contains { $0.contains("completion=normal") && $0.contains("release_observation=physical_eb") })
    }

    @Test @MainActor func observedYK8E00KeycodesMapToExpectedSkyworthButtons() {
        let monitor = SkyworthVoiceMonitor()
        var skyworthButtons: [SkyworthButton] = []
        var legacyButtons: [RemoteButton] = []
        var heldSnapshots: [Set<SkyworthButton>] = []
        monitor.onSkyworthButtonPress = { skyworthButtons.append($0) }
        monitor.onButtonPress = { legacyButtons.append($0) }
        monitor.onSkyworthHeldButtonsChange = { heldSnapshots.append($0) }

        let observedCodes: [UInt8] = [0x96, 0xF1, 0x80, 0x81, 0x65, 0xA0, 0xC9, 0xCA, 0x66]
        let empty: [UInt8] = [1, 0, 0, 0, 0, 0, 0, 0, 0]
        for code in observedCodes {
            let report: [UInt8] = [1, 0, 0, code, 0, 0, 0, 0, 0]
            report.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
            empty.withUnsafeBufferPointer { monitor.receiveButtons(reportID: 1, bytes: $0) }
        }
        #expect(skyworthButtons == [.ok, .back, .volumeUp, .volumeDown, .menu, .input, .multitask, .quickDots, .power])
        // Multitask (0xC9) and Quick Dots (0xCA) must not mislabel as TV or Play/Pause.
        #expect(legacyButtons == [.ok, .back, .volumeUp, .volumeDown, .menu, .input, .power])
        #expect(heldSnapshots.first == [.ok])
        #expect(heldSnapshots.last == [])
    }

    @Test func skyworthMappingStorePersistsGesturesAndPerAppProfiles() {
        let suiteName = "test.skyworth.mapping.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var config = SkyworthButtonMappingStore.loadConfiguration(from: defaults)
        #expect(config.globalGestures(for: .quickDots).singleClick == .action(.appSwitcher))
        #expect(config.globalGestures(for: .ok).longPress == .action(.commandReturn))

        config.appProfiles.append(SkyworthAppProfile(bundleIdentifier: "com.tencent.xinWeChat", displayName: "WeChat"))
        config.setBinding(.action(.commandReturn), for: .ok, gesture: .singleClick, appBundleID: "com.tencent.xinWeChat")
        config.setBinding(.action(.screenshot), for: .quickDots, gesture: .doubleClick, appBundleID: nil)
        SkyworthButtonMappingStore.saveConfiguration(config, to: defaults)

        let reloaded = SkyworthButtonMappingStore.loadConfiguration(from: defaults)
        #expect(reloaded.resolvedGestures(for: .ok, frontmostBundleID: "com.tencent.xinWeChat").singleClick == .action(.commandReturn))
        #expect(reloaded.resolvedGestures(for: .ok, frontmostBundleID: "com.apple.Safari").singleClick == .action(.returnKey))
        #expect(reloaded.resolvedGestures(for: .quickDots, frontmostBundleID: "com.tencent.xinWeChat").doubleClick == .action(.screenshot))
    }

    @Test @MainActor func skyworthGestureRecognizerHandlesSingleDoubleAndLongPress() async throws {
        let recognizer = SkyworthGestureRecognizer(doubleClickWindow: 0.08, longPressDuration: 0.08)
        var events: [(SkyworthButton, SkyworthGesture)] = []
        recognizer.onTrigger = { events.append(($0, $1)) }

        // Instant single-click when no double-click or long-press is bound.
        let instant = SkyworthButtonGestures(singleClick: .action(.returnKey))
        recognizer.handlePress(button: .ok, gestures: instant)
        recognizer.handleRelease(button: .ok)
        #expect(events.count == 1 && events[0].1 == .singleClick)

        // Long-press fires while held and suppresses release single-click.
        let withLong = SkyworthButtonGestures(singleClick: .action(.returnKey), longPress: .action(.commandReturn))
        recognizer.handlePress(button: .ok, gestures: withLong)
        try await Task.sleep(for: .milliseconds(120))
        recognizer.handleRelease(button: .ok)
        #expect(events.count == 2 && events[1].1 == .longPress)

        // Double-click cancels pending single-click.
        let withDouble = SkyworthButtonGestures(singleClick: .action(.escape), doubleClick: .action(.deleteBackward))
        recognizer.handlePress(button: .back, gestures: withDouble)
        recognizer.handleRelease(button: .back)
        try await Task.sleep(for: .milliseconds(25))
        recognizer.handlePress(button: .back, gestures: withDouble)
        recognizer.handleRelease(button: .back)
        try await Task.sleep(for: .milliseconds(120))
        #expect(events.count == 3 && events[2].1 == .doubleClick)
    }
}
