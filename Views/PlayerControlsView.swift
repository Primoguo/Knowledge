// Knowledge/Views/PlayerControlsView.swift
import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var speakerVM: SpeakerViewModel

    private let haptic = HapticService.shared

    var body: some View {
        VStack(spacing: 16) {
            // 主控制按钮
            HStack(spacing: 32) {
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
            HStack(spacing: 12) {
                ForEach(quickSpeeds, id: \.label) { preset in
                    Button(preset.label) {
                        haptic.speedChange()
                        var config = speakerVM.voiceConfig
                        config.rate = preset.value
                        speakerVM.updateConfig(config)
                    }
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        abs(speakerVM.voiceConfig.rate - preset.value) < 0.01
                            ? Color.accentColor
                            : Color.primary.opacity(0.05)
                    )
                    .foregroundColor(
                        abs(speakerVM.voiceConfig.rate - preset.value) < 0.01
                            ? .white
                            : .secondary
                    )
                    .cornerRadius(8)
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
                .font(.system(size: size == .large ? 28 : 22))
                .foregroundColor(size == .large ? .white : .primary)
                .frame(width: size == .large ? 64 : 40, height: size == .large ? 64 : 40)
                .background(
                    Group {
                        if size == .large {
                            Circle()
                                .fill(Color.accentColor)
                                .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 3)
                        }
                    }
                )
        }
    }
}
