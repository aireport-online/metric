import AVFoundation

/// Speelt de korte merkgeluiden af (startschot, finish, kudos).
/// Volgt de stille-schakelaar en mengt met muziek die al speelt.
@MainActor
final class SoundPlayer {
    enum Sound: String {
        case start
        case finish
        case kudos
    }

    static let shared = SoundPlayer()
    /// UserDefaults-sleutel van de schakelaar in Profiel; geluiden staan standaard aan.
    static let enabledKey = "soundsEnabled"

    private var players: [Sound: AVAudioPlayer] = [:]
    private var sessionConfigured = false

    private init() {}

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    func play(_ sound: Sound) {
        guard isEnabled else { return }
        if !sessionConfigured {
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
            sessionConfigured = true
        }
        if players[sound] == nil,
           let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.prepareToPlay()
            players[sound] = player
        }
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }
}
