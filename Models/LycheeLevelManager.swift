// Knowledge/Models/LycheeLevelManager.swift
import Foundation
import Combine

/// 荔枝成长体系管理器
/// 根据累计收听时长计算荔枝等级
final class LycheeLevelManager: ObservableObject {
    static let shared = LycheeLevelManager()

    @Published var totalMinutes: Int {
        didSet { UserDefaults.standard.set(totalMinutes, forKey: Self.key) }
    }

    @Published var currentLevel: LycheeLevel

    private static let key = "lycheeTotalListeningMinutes"

    /// 累计收听秒数（运行时，不持久化）
    private var accumulatedSeconds: TimeInterval = 0
    private var timer: Timer?

    private init() {
        let saved = UserDefaults.standard.integer(forKey: Self.key)
        self.totalMinutes = saved
        self.currentLevel = LycheeLevel.from(minutes: saved)
    }

    // MARK: - Tracking

    /// 开始追踪收听时间（播放时调用）
    func startTracking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.accumulatedSeconds += 1
            // 每分钟更新一次
            if Int(self.accumulatedSeconds) % 60 == 0 {
                self.totalMinutes += 1
                let newLevel = LycheeLevel.from(minutes: self.totalMinutes)
                if newLevel != self.currentLevel {
                    self.currentLevel = newLevel
                }
            }
        }
    }

    /// 停止追踪（暂停/停止时调用）
    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }
}
