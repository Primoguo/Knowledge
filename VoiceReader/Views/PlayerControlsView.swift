// Knowledge/Views/PlayerControlsView.swift
import SwiftUI

struct PlayerControlsView: View {
    @ObservedObject var speakerVM: SpeakerViewModel

    var body: some View {
        VStack(spacing: 16) {
            // 主控制按钮
            HStack(spacing: 32) {
                ControlButton(icon: "gobackward.15", size: .small) { speakerVM.skipBackward() }
                ControlButton(icon: playIcon, size: .large) { speakerVM.togglePlayPause() }
                ControlButton(icon: "goforward.30", size: .small) { speakerVM.skipForward() }
            }

            // 语速快捷切换
            HStack(spacing: 12) {
                ForEach(quickSpeeds, id: \.label) { preset in
                    Button(preset.label) {
                        var config = speakerVM.voiceConfig
                        config.rate = preset.value
                        speakerVM.updateConfig(config)
                    }
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(
                        abs(speakerVM.voiceConfig.rate - preset.value) < 0.01
                            ? Color.blue.opacity(0.2)
                            : Color.primary.opacity(0.06)
                    )
                    .foregroundColor(
                        abs(speakerVM.voiceConfig.rate - preset.value) < 0.01
                            ? .blue
                            : .secondary
                    )
                    .cornerRadius(6)
                }
            }
        }
    }

    private var playIcon: String {
        speakerVM.state == .playing ? "pause.fill" : "play.fill"
    }

    private let quickSpeeds: [(label: String, value: Float)] = [
        ("0.7x", 0.35), ("1x", 0.5), ("1.2x", 0.7), ("1.5x", 1.0), ("2x", 1.5),
    ]
}

private struct ControlButton: View {
    enum Size { case small, large }
    let icon: String; let size: Size; let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size == .large ? 28 : 22))
                .foregroundColor(.primary)
                .frame(width: size == .large ? 64 : 40, height: size == .large ? 64 : 40)
                .background(size == .large ? Circle().fill(Color.blue.opacity(0.12)) : Circle().fill(Color.clear))
        }
    }
}
