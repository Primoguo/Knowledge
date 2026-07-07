// Knowledge/Views/SystemVoiceSelectView.swift
import SwiftUI
import AVFoundation

/// 系统音色选择页面（iOS 17+ Neural TTS）
struct SystemVoiceSelectView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var voices: [SystemVoiceInfo] = []
    @State private var selectedVoiceId: String? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if #available(iOS 17.0, *) {
                    // iOS 17+ 显示所有可用音色
                    Section("推荐音色") {
                        ForEach(recommendedVoices) { voice in
                            voiceRow(voice: voice, isSelected: selectedVoiceId == voice.id) {
                                selectVoice(voice)
                            }
                        }
                    }
                    
                    Section("全部音色") {
                        ForEach(voices) { voice in
                            voiceRow(voice: voice, isSelected: selectedVoiceId == voice.id) {
                                selectVoice(voice)
                            }
                        }
                    }
                } else {
                    // iOS < 17 提示不支持
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            Text("Apple Neural TTS 需要 iOS 17+")
                                .font(.headline)
                            
                            Text("当前设备运行 iOS \(UIDevice.current.systemVersion)，请使用传统系统 TTS 或升级到 iOS 17 以体验更自然的语音合成。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("系统音色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { loadVoices() }
        }
    }
    
    // MARK: - Computed
    
    /// 推荐的 Neural 音色（优先展示）
    @available(iOS 17.0, *)
    private var recommendedVoices: [SystemVoiceInfo] {
        voices.filter { $0.isNeural && ($0.language.hasPrefix("zh-") || $0.language.hasPrefix("en-")) }
    }
    
    // MARK: - Actions
    
    private func loadVoices() {
        if #available(iOS 17.0, *) {
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
                .map { SystemVoiceInfo(voice: $0) }
                .sorted { $0.name < $1.name }
            
            voices = allVoices
            
            // 加载当前选中的音色
            if let currentId = speakerVM.voiceConfig.voiceIdentifier {
                selectedVoiceId = currentId
            } else {
                // 默认选择第一个 Neural 音色
                if let firstNeural = voices.first(where: { $0.isNeural }) {
                    selectedVoiceId = firstNeural.id
                }
            }
        } else {
            voices = []
        }
    }
    
    private func selectVoice(_ voice: SystemVoiceInfo) {
        selectedVoiceId = voice.id
        
        // 更新配置
        var config = speakerVM.voiceConfig
        config.voiceIdentifier = voice.id
        config.engine = .system  // 确保使用系统引擎
        speakerVM.updateConfig(config)
        
        // 保存到 UserDefaults
        saveVoiceSelection(voice.id)
    }
    
    private func saveVoiceSelection(_ identifier: String) {
        UserDefaults.standard.set(identifier, forKey: "selectedSystemVoiceIdentifier")
    }
    
    // MARK: - Row View
    
    @ViewBuilder
    private func voiceRow(
        voice: SystemVoiceInfo,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选择指示器
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    Image(systemName: isSelected ? "checkmark" : "waveform")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(voice.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if voice.isNeural {
                            Text("Neural")
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(3)
                        }
                    }
                    
                    Text("\(languageDisplayName(voice.language)) · \(voice.quality)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private func languageDisplayName(_ code: String) -> String {
        switch code {
        case "zh-CN": return "中文（简体）"
        case "zh-HK": return "中文（香港）"
        case "zh-TW": return "中文（繁体）"
        case "en-US": return "English (US)"
        case "en-GB": return "English (UK)"
        default: return code
        }
    }
}
