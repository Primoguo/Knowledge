// Knowledge/Services/ErrorHandler.swift
import Foundation
import Combine

/// 全局错误处理服务，提供统一的错误日志和用户提示
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    /// 当需要展示错误提示时发布
    @Published var currentAlert: AlertInfo?

    struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private init() {}

    /// 记录错误并通知 UI
    func handle(_ error: Error, context: String = "") {
        let message: String
        if let localized = error as? LocalizedError, let desc = localized.errorDescription {
            message = desc
        } else {
            message = error.localizedDescription
        }

        let prefix = context.isEmpty ? "" : "[\(context)] "
        print("❌ \(prefix)\(message)")

        Task { @MainActor in
            self.currentAlert = AlertInfo(title: "出错了", message: message)
        }
    }

    /// 仅打印日志（不弹窗）
    func log(_ message: String, level: LogLevel = .info) {
        let prefix: String
        switch level {
        case .debug: prefix = "🔍"
        case .info:  prefix = "ℹ️"
        case .warn:  prefix = "⚠️"
        case .error: prefix = "❌"
        }
        print("\(prefix) \(message)")
    }
}

enum LogLevel {
    case debug, info, warn, error
}
