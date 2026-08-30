import AppKit

@MainActor
protocol TimerTickSoundPlaying {
    func playTick(volume: Double)
}

@MainActor
struct TimerTickSoundPlayer: TimerTickSoundPlaying {
    func playTick(volume: Double) {
        guard volume > 0, let sound = NSSound(named: NSSound.Name("Tink")) else { return }
        sound.volume = Float(min(volume / 2, 1))
        sound.play()
    }
}
