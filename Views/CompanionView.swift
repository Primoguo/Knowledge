// Knowledge/Views/CompanionView.swift
import SwiftUI

/// AI 伴读对话视图 — 边听边问的交互界面
struct CompanionView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 下拉指示器
                pullHandle

                // 消息列表
                messagesList

                Divider()

                // 输入栏
                inputBar
            }
            .navigationTitle("AI 伴读")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // 播放/暂停切换按钮
                    Button(action: togglePlayback) {
                        HStack(spacing: 4) {
                            Image(systemName: speakerVM.state == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 12))
                            Text(speakerVM.state == .playing ? "暂停" : "播放")
                                .font(.subheadline)
                        }
                        .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            speakerVM.resetCompanion()
                        } label: {
                            Label("清空对话", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onAppear {
                inputFocused = true
                // 进入伴读时不自动暂停——支持边听边问
            }
            .onDisappear {
                // 退出伴读时不再自动恢复，播放状态由用户控制
            }
        }
    }

    // MARK: - Pull Handle

    /// 下拉指示器：提示用户可以下拉回到播放页
    private var pullHandle: some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 4)
            Text("↓ 下拉回到播放页")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            dismiss()
        }
    }

    // MARK: - Playback Toggle

    private func togglePlayback() {
        if speakerVM.state == .playing {
            speakerVM.pause()
        } else {
            speakerVM.play()
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    // 欢迎语（仅当对话为空时显示）
                    if speakerVM.companionMessages.isEmpty {
                        welcomeMessage
                    }

                    ForEach(speakerVM.companionMessages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: speakerVM.companionMessages.count) {
                if let last = speakerVM.companionMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Welcome

    private var welcomeMessage: some View {
        VStack(spacing: 8) {
            LycheeMascotView(size: 60, state: .waving)

            Text("荔枝伴读助手")
                .font(.headline)

            Text("你可以问我关于当前内容的任何问题\n朗读会自动暂停，回答完后可以继续")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // 快捷问题
            HStack(spacing: 8) {
                quickButton("这段讲了什么？")
                quickButton("解释一下关键概念")
            }
        }
        .padding(.vertical, 16)
    }

    private func quickButton(_ text: String) -> some View {
        Button(text) {
            sendQuestion(text)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundColor(.primary)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: CompanionMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.isUser {
                Spacer(minLength: 40)
            } else {
                // 荔枝头像（AI 消息）
                LycheeMascotView(
                    size: 28,
                    state: msg.isLoading ? .thinking : .idle,
                    enableEasterEgg: false
                )
            }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                // 角色标签
                Text(msg.isUser ? "你" : "荔枝")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // 消息内容
                Group {
                    if msg.isLoading {
                        HStack(spacing: 4) {
                            Text("荔枝思考中...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(msg.content)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(msg.isUser ? Color.primary.opacity(0.06) : Color(.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(16)
            }

            if !msg.isUser {
                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("问我任何问题...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .primary)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || speakerVM.isAskingCompanion)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendQuestion(text)
    }

    private func sendQuestion(_ question: String) {
        Task {
            await speakerVM.askCompanion(question: question)
        }
    }
}

