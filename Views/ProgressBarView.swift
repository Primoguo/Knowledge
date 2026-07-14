// Knowledge/Views/ProgressBarView.swift
import SwiftUI

/// 自定义进度条 — 带段落指示器 + 触觉反馈
/// 段落边界以小竖线标记在进度条上，拖拽经过段落时触发 Haptic
struct ProgressBarView: View {
    let progress: Double           // 0.0 ~ 1.0
    let paragraphPositions: [Double] // 每个段落在进度条中的归一化位置 (0.0 ~ 1.0)
    let onSeek: (Double) -> Void   // 拖拽/点击跳转回调

    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var lastParagraphIndex: Int = -1

    private let haptic = HapticService.shared

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 6
            let displayProgress = isDragging ? dragProgress : progress

            ZStack(alignment: .leading) {
                // 背景轨道
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: height)

                // 已播放进度
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(0, width * displayProgress), height: height)

                // 段落标记
                ForEach(paragraphPositions.indices, id: \.self) { index in
                    let x = width * paragraphPositions[index]
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(width: 1, height: height + 4)
                        .offset(x: x - 0.5, y: -2)
                }

                // 拖拽滑块 — 小荔枝
                Image("LycheeMascot")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isDragging ? 28 : 22, height: isDragging ? 28 : 22)
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .offset(x: max(0, width * displayProgress - (isDragging ? 14 : 11)))
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
            }
            .frame(height: 30)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = max(0, min(width, value.location.x))
                        let newProgress = x / width
                        if !isDragging {
                            isDragging = true
                            dragProgress = progress
                        }
                        dragProgress = newProgress

                        // 检测段落边界跨越
                        checkParagraphBoundary(newProgress)
                    }
                    .onEnded { value in
                        let x = max(0, min(width, value.location.x))
                        let finalProgress = x / width
                        onSeek(finalProgress)
                        isDragging = false
                    }
            )
        }
        .frame(height: 30)
    }

    // MARK: - Paragraph Boundary Detection

    /// 检测拖拽是否越过了段落边界，如果是则触发触觉反馈
    private func checkParagraphBoundary(_ progress: Double) {
        guard !paragraphPositions.isEmpty else { return }

        // 找到当前进度所在的段落索引
        var currentIndex = 0
        for (i, pos) in paragraphPositions.enumerated() {
            if progress >= pos {
                currentIndex = i
            }
        }

        // 段落索引变化 → 触发 Haptic
        if currentIndex != lastParagraphIndex {
            lastParagraphIndex = currentIndex
            haptic.paragraphBoundary()
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ProgressBarView(
            progress: 0.35,
            paragraphPositions: [0.0, 0.15, 0.3, 0.5, 0.7, 0.85],
            onSeek: { print("seek to \($0)") }
        )
        .padding(.horizontal, 24)
    }
}
