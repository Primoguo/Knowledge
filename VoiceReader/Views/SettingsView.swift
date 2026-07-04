// VoiceReader/Views/SettingsView.swift
import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @State private var rate: Double = 0.5
    @State private var pitch: Double = 1.0
    @State private var volume: Double = 1.0
    @State private var selectedLang = "zh-CN"
    @State private var voices: [AVSpeechSynthesisVoice] = []
    @State private var selectedVoice: String? = nil
    @State private var selectedEngine: TTSEngine = .system

    private let langs = [("zh-CN", "中文（普通话）"), ("zh-HK", "中文（粤语）"), ("en-US", "English (US)"), ("en-GB", "English (UK)"), ("ja-JP", "日本語"), ("ko-KR", "한국어")]

    var body: some View {
        NavigationStack {
            Form {
                Section("语音引擎") {
                    Picker("引擎", selection: $selectedEngine) {
                        ForEach(TTSEngine.allCases, id: \.self) { engine in
                            VStack(alignment: .leading) {
                                Text(engine.displayName)
                                Text(engine.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }.tag(engine)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedEngine) {
                        speakerVM.switchEngine(to: selectedEngine)
                        var config = speakerVM.voiceConfig
                        config.engine = selectedEngine
                        speakerVM.voiceConfig = config
                        saveConfig()
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
                        Slider(value: $rate, in: 0.1...2.0, step: 0.05).tint(.blue)
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
                                            ? Color.blue.opacity(0.15)
                                            : Color.gray.opacity(0.1)
                                    )
                                    .foregroundColor(
                                        abs(rate - Double(preset.value)) < 0.01
                                            ? .blue
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
                    Picker("语言", selection: $selectedLang) {
                        ForEach(langs, id: \.0) { code, name in Text(name).tag(code) }
                    }.onChange(of: selectedLang) { updateVoices(); apply() }
                    if !voices.isEmpty {
                        Picker("声音", selection: $selectedVoice) {
                            Text("默认").tag(nil as String?)
                            ForEach(voices, id: \.identifier) { v in Text(v.name).tag(v.identifier as String?) }
                        }.onChange(of: selectedVoice) { apply() }
                    }
                    if selectedEngine == .edge {
                        HStack {
                            Image(systemName: "info.circle.fill").foregroundColor(.blue).font(.caption)
                            Text("Edge TTS 使用微软 AI 语音，需要联网")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text("1.2.0").foregroundColor(.secondary) }
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
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, display: ((Double) -> String)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text(display?(value.wrappedValue) ?? String(format: format, value.wrappedValue)).foregroundColor(.secondary)
            }
            Slider(value: value, in: range, step: 0.05).tint(.blue)
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
            engine: selectedEngine
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
            engine: selectedEngine
        )
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "voiceConfig")
        }
    }
}
