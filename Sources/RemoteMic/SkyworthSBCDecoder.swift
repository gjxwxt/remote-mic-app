import Foundation
import SBCCodec

/// YK-8E00 0094:0013: report 0x5A contains two ordinary 60-byte SBC frames.
/// Each frame is 128 samples at 16 kHz. Never admit the older RC86 profile.
struct SkyworthSBCDecoder {
    private var context = sbc_t()

    mutating func reset() {
        sbc_reset(&context)
    }

    mutating func decode(reportID: UInt32, data: Data) -> [Int16]? {
        guard reportID == 0x5A, data.count == 121, data.first == 0x5A else { return nil }
        let bytes = Array(data.dropFirst())
        var next = context
        var output = [Int16](repeating: 0, count: 256)
        for offset in stride(from: 0, to: 120, by: 60) {
            var frame = sbc_frame()
            let accepted = bytes.withUnsafeBytes { input -> Bool in
                let source = input.baseAddress!.advanced(by: offset)
                guard bytes[offset] == 0x9C, sbc_probe(source, &frame) == 0,
                      !frame.msbc, frame.freq == SBC_FREQ_16K, frame.mode == SBC_MODE_MONO,
                      frame.nblocks == 16, frame.nsubbands == 8,
                      sbc_get_frame_size(&frame) == 60 else { return false }
                return output.withUnsafeMutableBufferPointer { samples in
                    sbc_decode(&next, source, 60, &frame,
                               samples.baseAddress!.advanced(by: offset / 60 * 128), 1,
                               nil, 0) == 0
                }
            }
            guard accepted else { return nil }
        }
        // Commit synthesis state only when both frames passed profile and CRC checks.
        context = next
        return output
    }
}
