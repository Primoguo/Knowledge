// Knowledge/Views/SystemVoiceSelectView.swift
import SwiftUI
import AVFoundation
import UIKit

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
                    
                    if recommendedVoices.isEmpty {
                        // 如果没有推荐的 Neural 音色，显示下载提示
                        downloadHintSection
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
    
    /// 推荐的 Neural 音色（优先展示，中文在前）
    @available(iOS 17.0, *)
    private var recommendedVoices: [SystemVoiceInfo] {
        let filtered = voices.filter { voice in
            // 放宽中文语言代码匹配：支持 zh、zh-CN、zh-TW、zh-HK、yue 等
            let isChinese = voice.language.hasPrefix("zh") || voice.language.hasPrefix("yue") || voice.language.hasPrefix("cmn")
            // 英文语言代码：en-US、en-GB、en-AU 等
            let isEnglish = voice.language.hasPrefix("en-")
            
            return voice.isNeural && (isChinese || isEnglish)
        }
        
        // 排序：中文在前，其他语言在后
        return filtered.sorted { voice1, voice2 in
            let isChinese1 = voice1.language.hasPrefix("zh") || voice1.language.hasPrefix("yue") || voice1.language.hasPrefix("cmn")
            let isChinese2 = voice2.language.hasPrefix("zh") || voice2.language.hasPrefix("yue") || voice2.language.hasPrefix("cmn")
            
            if isChinese1 && !isChinese2 {
                return true  // voice1 是中文，排前面
            } else if !isChinese1 && isChinese2 {
                return false  // voice2 是中文，排前面
            } else {
                return voice1.name < voice2.name  // 同类型按名称排序
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadVoices() {
        if #available(iOS 17.0, *) {
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
                .map { SystemVoiceInfo(voice: $0) }
                .sorted { $0.name < $1.name }
            
            voices = allVoices
            
            // 检查是否有中文 Neural TTS 音色
            let hasChineseNeural = voices.contains { voice in
                let isChinese = voice.language.hasPrefix("zh") || voice.language.hasPrefix("yue") || voice.language.hasPrefix("cmn")
                return isChinese && voice.isNeural
            }
            
            // 调试信息：打印所有中文相关音色
            print("\n=== 中文音色调试信息 ===")
            let chineseVoices = voices.filter { voice in
                voice.language.hasPrefix("zh") || voice.language.hasPrefix("yue") || voice.language.hasPrefix("cmn")
            }
            print("总计中文相关音色: \(chineseVoices.count)")
            for voice in chineseVoices {
                let neuralTag = voice.isNeural ? " [Neural]" : ""
                print("  - \(voice.name) (\(voice.language))\(neuralTag)")
            }
            print("=========================\n")
            
            // 加载当前选中的音色
            if let currentId = speakerVM.voiceConfig.voiceIdentifier {
                selectedVoiceId = currentId
            } else {
                // 默认选择第一个 Neural 音色
                if let firstNeural = voices.first(where: { $0.isNeural }) {
                    selectedVoiceId = firstNeural.id
                }
            }
            
            // 如果没有中文 Neural 音色，显示下载提示
            if !hasChineseNeural {
                print("⚠️ 未检测到中文 Neural TTS 音色，需要手动下载")
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
    
    // MARK: - Download Hint
    
    @available(iOS 17.0, *)
    private var downloadHintSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("需要下载 Neural TTS 音色")
                        .font(.headline)
                }
                
                Text("Apple Neural TTS 音色需要手动下载。请按以下步骤操作：\n\n1. 打开「设置」→「辅助功能」→「朗读内容」\n2. 点击「声音」→「中文」\n3. 选择你喜欢的 Neural 音色并下载\n4. 返回本页面重新加载")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                
                Button(action: openSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("前往系统设置")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.vertical, 8)
        } header: {
            Text("提示")
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
