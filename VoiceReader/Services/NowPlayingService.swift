// VoiceReader/Services/NowPlayingService.swift
import MediaPlayer

final class NowPlayingService {
    static let shared = NowPlayingService()

    var onPlayPause: (() -> Void)?
    var onSkipForward: (() -> Void)?
    var onSkipBackward: (() -> Void)?

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()

    private init() {
        setupCommands()
    }

    func update(title: String, duration: TimeInterval, elapsed: TimeInterval, rate: Float) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = "有声阅读器"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audioBook.rawValue
        infoCenter.nowPlayingInfo = info
    }

    func clear() {
        infoCenter.nowPlayingInfo = nil
    }

    private func setupCommands() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.onPlayPause?(); return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.onPlayPause?(); return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onPlayPause?(); return .success
        }
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.onSkipForward?(); return .success
        }
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.onSkipBackward?(); return .success
        }
        // 禁用不需要的命令
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
    }
}
