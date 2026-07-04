// Knowledge/App/AppDelegate.swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 仅配置 category，不激活 session（按需激活，避免过早占用）
        AudioSessionService.shared.configure()
        return true
    }
}
