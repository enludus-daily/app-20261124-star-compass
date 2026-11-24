import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 真鍮の天文台：押す＝小さな歯車のカチ、ピン＝金属のチン、近い答え＝鈴が上がる、遠い答え＝低い 2 音、
/// 新しい読み方の札＝鈴の 5 音、5 問を終える＝4 音。消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap, pin, near, far, lore, finish
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階：触る 0.25・ピン 0.4・遠い 0.5・近い 0.7・札/完了 0.8
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap: 0.25
        case .pin: 0.4
        case .far: 0.5
        case .near: 0.7
        case .lore, .finish: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        return (try? engine.start()) != nil
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private struct Tone {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var glide: Double? = nil
    }

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            // 歯車のカチ：短い雑音と高い音
            return render(0.05, noise: 0.09, noiseDecay: 160, tones: [Tone(freq: 2400, amp: 0.1, decay: 120)])
        case .pin:
            // 真鍮のチン：倍音の多い金属
            return render(0.7, noise: 0.03, noiseDecay: 200, tones: [Tone(freq: 1568, amp: 0.22, decay: 7), Tone(freq: 1568 * 2.76, amp: 0.07, decay: 12), Tone(freq: 1568 * 5.4, amp: 0.03, decay: 20)])
        case .near:
            let notes = [587.3, 880.0, 1174.7, 1760.0]
            return render(1.4, noise: 0, tones: notes.enumerated().flatMap { i, f in
                [Tone(freq: f, amp: 0.2, decay: 3.2, delay: Double(i) * 0.08), Tone(freq: f * 2.76, amp: 0.04, decay: 8, delay: Double(i) * 0.08)]
            })
        case .far:
            return render(0.8, noise: 0, tones: [Tone(freq: 392, amp: 0.22, decay: 5), Tone(freq: 293.7, amp: 0.22, decay: 4, delay: 0.18)])
        case .lore:
            let notes = [784.0, 987.8, 1174.7, 1568.0, 1975.5]
            return render(1.6, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.2, decay: 3, delay: Double(i) * 0.1) })
        case .finish:
            let notes = [523.3, 659.3, 784.0, 1046.5]
            return render(1.3, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.22, decay: 3.5, delay: Double(i) * 0.12) })
        }
    }

    private func render(_ seconds: Double, noise: Double, noiseDecay: Double = 60, tones: [Tone]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRNG(seed: 22)
        var phases = Array(repeating: 0.0, count: tones.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in tones.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.glide {
                    let x = min(1, local / max(0.01, seconds - p.delay))
                    f = p.freq + (to - p.freq) * x
                }
                phases[k] += 2 * .pi * f / rate
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = rng.unit() * 2 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
