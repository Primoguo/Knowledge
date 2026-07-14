// Knowledge/Views/DocumentCardView.swift
import SwiftUI

/// 书库卡片视图 — Notion 风格：极简白底 + 细边框
struct DocumentCardView: View {
    let document: Document
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 文件类型图标
            HStack {
                Image(systemName: document.fileType.iconName)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)

                Spacer()

                // 播放状态指示
                if isPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .symbolEffect(.variableColor.iterative)
                        Text("播放中")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.accentColor)
                }
            }

            // 标题
            Text(document.title)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
                .frame(height: 38, alignment: .top)

            Spacer(minLength: 0)

            // 底部信息栏
            HStack(spacing: 8) {
                Text(document.fileType.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text("·")
                    .foregroundColor(.secondary.opacity(0.4))

                Text(formatLen(document.totalLength))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                // 进度百分比
                if document.progress > 0 {
                    Text("\(Int(document.progress * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                }
            }

            // 进度条（有进度时才显示）
            if document.progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.08))
                            .frame(height: 2)
                        Capsule()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: geo.size.width * document.progress, height: 2)
                    }
                }
                .frame(height: 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPlaying ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.12), lineWidth: isPlaying ? 1.5 : 0.5)
        )
    }

    // MARK: - Helpers

    private func formatLen(_ len: Int) -> String {
        if len >= 10000 { return String(format: "%.1f万字", Double(len) / 10000.0) }
        else if len >= 1000 { return String(format: "%.1f千字", Double(len) / 1000.0) }
        return "\(len)字"
    }
}

/// 按压缩放按钮样式 — 点击时轻微缩小
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: 12) {
        DocumentCardView(
            document: Document(title: "三体第一章", fileName: "santi.pdf", fileType: .pdf, extractedText: String(repeating: "测试", count: 5000)),
            isPlaying: false
        )
        DocumentCardView(
            document: Document(title: "SwiftUI 教程", fileName: "swiftui.txt", fileType: .txt, extractedText: String(repeating: "测试", count: 1500)),
            isPlaying: true
        )
    }
    .padding()
}
