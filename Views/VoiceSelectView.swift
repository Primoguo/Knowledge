// Knowledge/Views/VoiceSelectView.swift
import SwiftUI

/// 音色选择页面
struct VoiceSelectView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPresetId: String? = nil
    @State private var selectedCloneId: String? = nil
    @State private var clonedVoices: [ClonedVoice] = []
    @State private var showCloneView = false
    @State private var previewPlayingId: String? = nil
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                // 我的克隆音色
                if !clonedVoices.isEmpty {
                    Section("我的音色") {
                        ForEach(clonedVoices) { voice in
                            voiceRow(
                                id: voice.id,
                                name: voice.name,
                                description: voice.description ?? "",
                                isSelected: selectedCloneId == voice.id
                            ) {
                                selectedCloneId = voice.id
                                selectedPresetId = nil
                                applyCloneVoice(voice.id)
                            }
                        }
                        .onDelete(perform: deleteCloneVoice)
                    }
                }

                // 克隆新声音
                Section {
                    Button(action: { showCloneView = true }) {
                        Label("录制我的声音", systemImage: "mic.badge.plus")
                            .foregroundColor(.accentColor)
                    }
                }

                // 预设音色（按分类）
                ForEach(VoiceStore.presetsByCategory(), id: \.category.rawValue) { category, voices in
                    Section(category.rawValue) {
                        ForEach(voices) { voice in
                            voiceRow(
                                id: voice.id,
                                name: voice.name,
                                description: voice.description,
                                isSelected: selectedPresetId == voice.id
                            ) {
                                selectedPresetId = voice.id
                                selectedCloneId = nil
                                applyPresetVoice(voice.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("音色选择")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                loadCurrentSelection()
                clonedVoices = VoiceStore.loadClonedVoices()
            }
            .sheet(isPresented: $showCloneView) {
                VoiceCloneView()
            }
        }
    }

    @ViewBuilder
    private func voiceRow(
        id: String,
        name: String,
        description: String,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            // 选择指示
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                            .frame(width: 40, height: 40)
                        Image(systemName: isSelected ? "checkmark" : "person.wave.2.fill")
                            .font(.system(size: 16))
                            .foregroundColor(isSelected ? .white : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // 试听按钮
            Button(action: { togglePreview(voiceId: id) }) {
                Image(systemName: previewPlayingId == id ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(previewPlayingId == id ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func loadCurrentSelection() {
        let config = speakerVM.voiceConfig
        if config.engine == .knowledgeVoice {
            if let cloneId = config.clonedVoiceId {
                selectedCloneId = cloneId
            }
            if let presetId = config.presetVoiceId {
                selectedPresetId = presetId
            }
        }
    }

    private func applyPresetVoice(_ voiceId: String) {
        var config = speakerVM.voiceConfig
        config.engine = .knowledgeVoice
        config.presetVoiceId = voiceId
        config.clonedVoiceId = nil
        speakerVM.voiceConfig = config
        speakerVM.switchEngine(to: .knowledgeVoice)
        VoiceStore.saveSelectedPreset(voiceId)
        VoiceStore.saveSelectedClone(nil)
    }

    private func applyCloneVoice(_ voiceId: String) {
        var config = speakerVM.voiceConfig
        config.engine = .knowledgeVoice
        config.clonedVoiceId = voiceId
        config.presetVoiceId = nil
        speakerVM.voiceConfig = config
        speakerVM.switchEngine(to: .knowledgeVoice)
        VoiceStore.saveSelectedClone(voiceId)
        VoiceStore.saveSelectedPreset(nil)
    }

    private func togglePreview(voiceId: String) {
        if previewPlayingId == voiceId {
            previewTask?.cancel()
            previewPlayingId = nil
            return
        }

        previewTask?.cancel()
        previewPlayingId = voiceId

        previewTask = Task {
            do {
                let audioData = try await CosyVoiceService.shared.previewVoice(voiceId: voiceId)
                guard !Task.isCancelled else { return }

                // 播放预览音频
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice_preview_\(UUID().uuidString).mp3")
                try audioData.write(to: tempURL)

                await MainActor.run {
                    let player = try? AVAudioPlayer(contentsOf: tempURL)
                    player?.play()
                }

                // 播放完成后重置状态
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    if previewPlayingId == voiceId {
                        previewPlayingId = nil
                    }
                }
            } catch {
                await MainActor.run {
                    previewPlayingId = nil
                }
            }
        }
    }

    private func deleteCloneVoice(at offsets: IndexSet) {
        clonedVoices.remove(atOffsets: offsets)
        VoiceStore.saveClonedVoices(clonedVoices)
        if selectedCloneId != nil && !clonedVoices.contains(where: { $0.id == selectedCloneId }) {
            selectedCloneId = nil
        }
    }
}

import AVFoundation
