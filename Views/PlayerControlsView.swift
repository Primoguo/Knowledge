// Knowledge/Views/PlayerControlsView.swift
import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var speakerVM: SpeakerViewModel

    private let haptic = HapticService.shared

    var body: some View {
        VStack(spacing: 20) {
            // 主控制按钮
            HStack(spacing: 40) {
                ControlButton(icon: "gobackward.15", size: .small) {
                    haptic.skip()
                    speakerVM.skipBackward()
                }
                ControlButton(icon: playIcon, size: .large) {
                    haptic.playPause()
                    speakerVM.togglePlayPause()
                }
                ControlButton(icon: "goforward.30", size: .small) {
                    haptic.skip()
                    speakerVM.skipForward()
                }
            }

            // 语速快捷切换
            HStack(spacing: 8) {
                ForEach(quickSpeeds, id: \.label) { preset in
                    let isActive = abs(speakerVM.voiceConfig.rate - preset.value) < 0.01
                    Button(preset.label) {
                        haptic.speedChange()
                        var config = speakerVM.voiceConfig
                        config.rate = preset.value
                        speakerVM.updateConfig(config)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .foregroundColor(isActive ? .primary : .secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActive ? Color.secondary.opacity(0.12) : Color.clear)
                    )
                }
            }
        }
    }

    private var playIcon: String {
        speakerVM.state == .playing ? "pause.fill" : "play.fill"
    }

    private let quickSpeeds: [(label: String, value: Float)] = [
        ("1x", 0.5), ("1.2x", 0.7), ("1.5x", 1.0), ("2x", 1.5),
    ]
}

private struct ControlButton: View {
    enum Size { case small, large }
    let icon: String; let size: Size; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size == .large ? 26 : 20, weight: .light))
                .foregroundColor(.primary)
                .frame(width: size == .large ? 60 : 40, height: size == .large ? 60 : 40)
                .background(
                    Group {
                        if size == .large {
                            Circle()
                                .fill(Color.primary.opacity(0.06))
                        }
                    }
                )
        }
    }
}
