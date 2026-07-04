// VoiceReader/Services/AudioSessionService.swift
import AVFoundation

final class AudioSessionService {
    static let shared = AudioSessionService()
    private init() {}

    func activate() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession 激活失败: \(error)")
        }
    }

    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession 停用失败: \(error)")
        }
    }
}
