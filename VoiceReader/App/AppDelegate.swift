// VoiceReader/App/AppDelegate.swift
import UIKit
import AVFoundation

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetoothHFP, .allowAirPlay]
            )
            try session.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
        return true
    }
}
