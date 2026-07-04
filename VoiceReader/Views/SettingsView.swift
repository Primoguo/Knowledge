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

    private let langs = [("zh-CN", "中文（普通话）"), ("zh-HK", "中文（粤语）"), ("en-US", "English (US)"), ("en-GB", "English (UK)"), ("ja-JP", "日本語"), ("ko-KR", "한국어")]

    var body: some View {
        NavigationStack {
            Form {
                Section("朗读设置") {
                    sliderRow("语速", value: $rate, range: 0.1...1.0, format: "%.1fx")
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
                }
                Section("关于") {
                    HStack { Text("版本"); Spacer(); Text("1.0.0").foregroundColor(.secondary) }
                }
            }
            .navigationTitle("设置")
            .onAppear {
                let c = speakerVM.voiceConfig
                rate = Double(c.rate); pitch = Double(c.pitchMultiplier); volume = Double(c.volume)
                selectedLang = c.language; selectedVoice = c.voiceIdentifier
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
        let config = VoiceConfig(rate: Float(rate), pitchMultiplier: Float(pitch), volume: Float(volume), language: selectedLang, voiceIdentifier: selectedVoice)
        speakerVM.voiceConfig = config
        // 仅在播放中才实时更新 TTS 引擎
        guard speakerVM.state == .playing else { return }
        speakerVM.updateConfig(config)
    }
}
