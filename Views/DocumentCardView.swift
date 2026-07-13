// Knowledge/Views/DocumentCardView.swift
import SwiftUI

/// 书库卡片视图 — 网格布局中的单个文档卡片
struct DocumentCardView: View {
    let document: Document
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 文件类型图标 + 标签
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: document.fileType.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                }

                Spacer()

                // 播放状态指示
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .symbolEffect(.variableColor.iterative)
                }
            }

            // 标题
            Text(document.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .foregroundColor(isPlaying ? .accentColor : .primary)
                .frame(height: 40, alignment: .top)

            // 底部信息栏
            HStack {
                // 文件类型标签
                Text(document.fileType.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                // 字数
                Text(formatLen(document.totalLength))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // 进度条（有进度时才显示）
            if document.progress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 3)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * document.progress, height: 3)
                    }
                }
                .frame(height: 3)
            } else {
                // 无进度时占位，保持卡片高度一致
                Color.clear.frame(height: 3)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlaying ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Styles

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }

    private var iconColor: Color {
        switch document.fileType.iconColor {
        case "red":    return .red
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "purple": return .purple
        case "teal":   return .teal
        default:       return .gray
        }
    }

    private func formatLen(_ len: Int) -> String {
        if len >= 10000 { return String(format: "%.1f万字", Double(len) / 10000.0) }
        else if len >= 1000 { return String(format: "%.1f千字", Double(len) / 1000.0) }
        return "\(len)字"
    }
}

/// 按压缩放按钮样式 — 点击时轻微缩小，提供触觉反馈感
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
