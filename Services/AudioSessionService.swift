// Knowledge/Services/AudioSessionService.swift
import AVFoundation

/// 统一管理 AVAudioSession 的配置、激活和停用
/// AppDelegate 只负责调用，不直接操作 AudioSession
final class AudioSessionService {
    static let shared = AudioSessionService()

    private let session = AVAudioSession.sharedInstance()
    private var isConfigured = false

    private init() {}

    /// 配置 AudioSession 为播放模式（后台播放、蓝牙、AirPlay）
    func configure() {
        guard !isConfigured else { return }
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.allowBluetoothHFP, .allowAirPlay]
            )
            isConfigured = true
        } catch {
            print("❌ AudioSession 配置失败: \(error.localizedDescription)")
        }
    }

    func activate() {
        configure() // 确保已配置
        do {
            try session.setActive(true)
        } catch {
            print("❌ AudioSession 激活失败: \(error.localizedDescription)")
        }
    }

    func deactivate() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ AudioSession 停用失败: \(error.localizedDescription)")
        }
    }
}
