// VoiceReader/ViewModels/SpeakerViewModel.swift
import Foundation
import Combine

@MainActor
final class SpeakerViewModel: ObservableObject {

    @Published var state: PlaybackState = .idle
    @Published var currentDocument: Document?
    @Published var progress: Double = 0.0
    @Published var currentPositionText: String = "00:00"
    @Published var voiceConfig: VoiceConfig = .default

    private let speechService = SpeechService()
    private let nowPlaying = NowPlayingService.shared
    private let audioSession = AudioSessionService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentPosition = 0

    init() {
        setupBindings()
    }

    func loadDocument(_ document: Document) {
        stop()
        currentDocument = document
        voiceConfig = loadConfig()
        progress = document.progress
        currentPosition = document.currentPosition
        updatePositionText()
    }

    func togglePlayPause() {
        switch state {
        case .idle, .paused: play()
        case .playing: pause()
        case .finished: replay()
        }
    }

    func play() {
        guard let doc = currentDocument, !doc.extractedText.isEmpty else { return }
        audioSession.activate()
        if state == .paused {
            speechService.resume()
        } else {
            speechService.speak(text: doc.extractedText, from: doc.currentPosition, config: voiceConfig)
        }
        updateNowPlaying()
    }

    func pause() {
        speechService.pause()
        savePosition()
    }

    func stop() {
        speechService.stop()
        audioSession.deactivate()
        nowPlaying.clear()
        savePosition()
    }

    func replay() {
        guard let doc = currentDocument else { return }
        doc.currentPosition = 0
        currentPosition = 0
        savePosition()
        play()
    }

    func skipForward() { speechService.skipForward(by: 30) }
    func skipBackward() { speechService.skipBackward(by: 15) }

    func seekTo(progress: Double) {
        guard let doc = currentDocument else { return }
        let target = Int(Double((doc.extractedText as NSString).length) * progress)
        speechService.stop()
        if state == .playing || state == .paused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.speechService.speak(text: doc.extractedText, from: target, config: self?.voiceConfig ?? .default)
            }
        } else {
            // 如果不在播放中，只更新位置不启动播放
            currentPosition = target
            updateProgress(target)
            savePosition()
        }
    }

    func updateConfig(_ config: VoiceConfig) {
        voiceConfig = config
        saveConfig(config)
        guard state == .playing, let doc = currentDocument else { return }
        let pos = currentPosition
        speechService.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.speechService.speak(text: doc.extractedText, from: pos, config: config)
        }
    }

    // MARK: - Private
    private func setupBindings() {
        speechService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] s in
                self?.state = s
                if s == .finished || s == .idle { self?.savePosition() }
            }
            .store(in: &cancellables)

        speechService.onPositionChange = { [weak self] pos in
            Task { @MainActor in
                self?.currentPosition = pos
                self?.updateProgress(pos)
                self?.updateNowPlaying()
            }
        }

        nowPlaying.onPlayPause = { [weak self] in Task { @MainActor in self?.togglePlayPause() } }
        nowPlaying.onSkipForward = { [weak self] in Task { @MainActor in self?.skipForward() } }
        nowPlaying.onSkipBackward = { [weak self] in Task { @MainActor in self?.skipBackward() } }
    }

    private func updateProgress(_ position: Int) {
        guard let doc = currentDocument else { return }
        doc.currentPosition = position
        let len = (doc.extractedText as NSString).length
        if len > 0 {
            progress = Double(position) / Double(len)
            doc.progress = progress
        }
        updatePositionText()
    }

    private func updatePositionText() {
        let sec = currentPosition / 3
        currentPositionText = String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    private func updateNowPlaying() {
        guard let doc = currentDocument else { return }
        let len = (doc.extractedText as NSString).length
        nowPlaying.update(
            title: doc.title,
            duration: TimeInterval(len / 3),
            elapsed: TimeInterval(currentPosition / 3),
            rate: state == .playing ? 1.0 : 0.0
        )
    }

    private func savePosition() {
        guard let doc = currentDocument else { return }
        doc.currentPosition = currentPosition
        doc.progress = progress
        doc.lastOpenedDate = Date()
    }

    private func loadConfig() -> VoiceConfig {
        guard let data = UserDefaults.standard.data(forKey: "voiceConfig"),
              let c = try? JSONDecoder().decode(VoiceConfig.self, from: data) else { return .default }
        return c
    }

    private func saveConfig(_ config: VoiceConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "voiceConfig")
        }
    }
}
