// Knowledge/Views/CompanionView.swift
import SwiftUI

/// AI 伴读对话视图 — 边听边问的交互界面
struct CompanionView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    Button("继续听") { dismiss() }
                        .foregroundColor(.accentColor)
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
            .onAppear {
                // 进入伴读时暂停朗读
                if speakerVM.state == .playing {
                    speakerVM.pause()
                }
                inputFocused = true
            }
            .onDisappear {
                // 退出伴读时恢复朗读
                if speakerVM.companionPausedPlay {
                    speakerVM.play()
                    speakerVM.companionPausedPlay = false
                }
            }
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
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)

            Text("AI 伴读助手")
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
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.1))
        .foregroundColor(.accentColor)
        .cornerRadius(14)
    }

    // MARK: - Message Bubble

    private func messageBubble(_ msg: CompanionMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.isUser {
                Spacer(minLength: 40)
            }

            VStack(alignment: msg.isUser ? .trailing : .leading, spacing: 4) {
                // 角色标签
                Text(msg.isUser ? "你" : "AI 伴读")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // 消息内容
                Group {
                    if msg.isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("思考中...")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(msg.content)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(msg.isUser ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(msg.isUser ? .white : .primary)
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
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
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

