// Knowledge/Services/ThemeManager.swift
import SwiftUI
import Combine

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let defaultsKey = "themeMode"

    @Published var mode: ThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: defaultsKey)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let saved = ThemeMode(rawValue: raw) {
            self.mode = saved
        } else {
            self.mode = .system
        }
    }
}
