// Knowledge/Views/SettingsView.swift
import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var rate: Double = 0.5
    @State private var pitch: Double = 1.0
    @State private var volume: Double = 1.0
    @State private var selectedLang = "zh-CN"
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoice: String? = nil
    @State private var selectedEngine: TTSEngine = .system
    @State private var showVoiceSelect = false
    @State private var showSystemVoiceSelect = false

    private let langs = [("zh-CN", "中文（普通话）"), ("zh-HK", "中文（粤语）"), ("en-US", "English (US)"), ("en-GB", "English (UK)"), ("ja-JP", "日本語"), ("ko-KR", "한국어")]

    var body: some View {
        NavigationStack {
            Form {
                Section("外观") {
                    ForEach(ThemeMode.allCases, id: \.self) { theme in
                        Button(action: { themeManager.mode = theme }) {
                            HStack {
                                Image(systemName: theme.iconName)
                                    .frame(width: 28)
                                    .foregroundColor(.accentColor)
                                Text(theme.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if themeManager.mode == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // MARK: - Premium 订阅
                Section {
                    if subscriptionManager.isPremium {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premium 已激活")
                                    .fontWeight(.semibold)
                                Text("全部 AI 功能已解锁")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LinearGradient(
                                            colors: [.accentColor.opacity(0.8), .accentColor.opacity(0.5)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("解锁 Premium")
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("AI 总结、AI 伴读、高品质音色")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Premium 功能")
                } footer: {
                    if !subscriptionManager.isPremium {
                        Text("订阅后可使用全部 AI 功能")
                    }
                }

                Section("语音引擎") {
                    ForEach(TTSEngine.allCases.filter { $0.isSupported }, id: \.self) { engine in
                        // Knowledge Voice 标记为即将推出（灰化不可选）
                        if engine == .knowledgeVoice {
                            comingSoonEngineRow(engine: engine)
                        } else {
                            Button(action: {
                                selectedEngine = engine
                                speakerVM.switchEngine(to: engine)
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(engine.displayName)
                                        Text(engine.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if selectedEngine == engine {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                    // 标注推荐选项
                                    if engine == .system {
                                        Text("推荐")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .cornerRadius(4)
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("朗读设置") {
                    // 语速 + 快捷档位
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("语速")
                            Spacer()
                            Text(String(format: "%.1fx", rate)).foregroundColor(.secondary)
                        }
                        Slider(value: $rate, in: 0.1...2.0, step: 0.05).tint(.accentColor)
                            .onChange(of: rate) { apply() }
                        // 快捷档位
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VoiceConfig.speedPresets, id: \.label) { preset in
                                    Button(preset.label) {
                                        rate = Double(preset.value)
                                        apply()
                                    }
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(
                                        abs(rate - Double(preset.value)) < 0.01
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.gray.opacity(0.1)
                                    )
                                    .foregroundColor(
                                        abs(rate - Double(preset.value)) < 0.01
                                            ? .accentColor
                                            : .secondary
                                    )
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    sliderRow("音高", value: $pitch, range: 0.5...2.0, format: "%.1f")
                    sliderRow("音量", value: $volume, range: 0.0...1.0, format: "%.0f%%") { "\(Int($0 * 100))%" }
                }

                Section("语音选择") {
                    // Apple Neural TTS 音色选择入口（仅 iOS 17+）
                    if #available(iOS 17.0, *), selectedEngine == .system {
                        Button(action: { showSystemVoiceSelect = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("系统音色")
                                        .font(.body)
                                    Text("选择 Neural 增强版音色")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Knowledge Voice 音色选择入口
                    if selectedEngine == .knowledgeVoice {
                        Button(action: { showVoiceSelect = true }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI 音色")
                                        .font(.body)
                                    Text("选择 CosyVoice 预设或克隆音色")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // 传统语言选择（降级兼容）
                    if selectedEngine == .legacySystem {
                        Picker("语言", selection: $selectedLang) {
                            ForEach(langs, id: \.0) { code, name in Text(name).tag(code) }
                        }.onChange(of: selectedLang) { updateVoices(); apply() }
                        if !voices.isEmpty {
                            Picker("声音", selection: $selectedVoice) {
                                Text("默认").tag(nil as String?)
                                ForEach(voices, id: \.identifier) { v in Text(v.name).tag(v.identifier as String?) }
                            }.onChange(of: selectedVoice) { apply() }
                        }
                    }
                }
                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text("2.0.0").foregroundColor(.secondary) }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                let c = speakerVM.voiceConfig
                rate = Double(c.rate); pitch = Double(c.pitchMultiplier); volume = Double(c.volume)
                selectedLang = c.language; selectedVoice = c.voiceIdentifier
                selectedEngine = c.engine
                updateVoices()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showVoiceSelect) {
                VoiceSelectView(speakerVM: speakerVM)
            }
            .sheet(isPresented: $showSystemVoiceSelect) {
                SystemVoiceSelectView(speakerVM: speakerVM)
            }
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, display: ((Double) -> String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text(display?(value.wrappedValue) ?? String(format: format, value.wrappedValue)).foregroundColor(.secondary)
            }
            Slider(value: value, in: range, step: 0.05).tint(.accentColor)
                .onChange(of: value.wrappedValue) { apply() }
        }
    }

    private func updateVoices() {
        voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(String(selectedLang.prefix(2))) }
    }

    private func apply() {
        let config = VoiceConfig(
            rate: Float(rate),
            pitchMultiplier: Float(pitch),
            volume: Float(volume),
            language: selectedLang,
            voiceIdentifier: selectedVoice,
            engine: selectedEngine,
            clonedVoiceId: selectedEngine == .knowledgeVoice ? VoiceStore.loadSelectedClone() : nil,
            presetVoiceId: selectedEngine == .knowledgeVoice ? VoiceStore.loadSelectedPreset() : nil
        )
        speakerVM.voiceConfig = config
        saveConfig()
        // 仅在播放中才实时更新 TTS 引擎
        guard speakerVM.state == .playing else { return }
        speakerVM.updateConfig(config)
    }

    private func saveConfig() {
        let config = VoiceConfig(
            rate: Float(rate),
            pitchMultiplier: Float(pitch),
            volume: Float(volume),
            language: selectedLang,
            voiceIdentifier: selectedVoice,
            engine: selectedEngine,
            clonedVoiceId: selectedEngine == .knowledgeVoice ? VoiceStore.loadSelectedClone() : nil,
            presetVoiceId: selectedEngine == .knowledgeVoice ? VoiceStore.loadSelectedPreset() : nil
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "voiceConfig")
        }
    }
    
    // MARK: - Coming Soon Engine Row
    
    @ViewBuilder
    private func comingSoonEngineRow(engine: TTSEngine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(engine.displayName)
                        .foregroundColor(.primary)
                    
                    Text("即将推出")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                        .foregroundColor(.orange)
                }
                
                Text(engine.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 禁用状态图标
            Image(systemName: "lock.fill")
                .foregroundColor(.gray)
        }
        .opacity(0.6)  // 整体半透明效果
        .disabled(true)  // 禁用点击
    }
}
