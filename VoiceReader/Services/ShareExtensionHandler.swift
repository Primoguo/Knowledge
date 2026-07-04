// VoiceReader/Services/ShareExtensionHandler.swift
import Foundation

/// 处理从 Share Extension 传入的分享内容
final class ShareExtensionHandler: ObservableObject {
    static let shared = ShareExtensionHandler()

    @Published var pendingURL: String?
    @Published var pendingText: String?

    private let sharedDefaults = UserDefaults(suiteName: "group.com.voicereader.app")

    private init() {}

    /// 检查是否有待处理的分享内容
    func checkPendingContent() {
        guard let defaults = sharedDefaults else { return }

        if let url = defaults.string(forKey: "pendingShareURL"), !url.isEmpty {
            pendingURL = url
            defaults.removeObject(forKey: "pendingShareURL")
            defaults.synchronize()
            return
        }

        if let text = defaults.string(forKey: "pendingShareText"), !text.isEmpty {
            pendingText = text
            defaults.removeObject(forKey: "pendingShareText")
            defaults.synchronize()
            return
        }
    }
}
