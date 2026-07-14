// Knowledge/Views/LycheeMascotView.swift
import SwiftUI

/// 荔枝吉祥物状态
enum MascotState {
    case idle       // 微微呼吸缩放
    case listening  // 左右轻摇（播放中）
    case thinking   // 叶子转动 + 缩放（AI 思考中）
    case happy      // 弹跳 + 放大（任务完成）
    case sleeping   // 倾斜 + Zzz 气泡（空状态/闲置）
    case surprised  // 放大抖动（快进快退）
    case waving     // 旋转摇摆（欢迎）
}

/// 荔枝等级
enum LycheeLevel: Int {
    case small = 0   // 0~60 分钟
    case medium = 1  // 60~300 分钟
    case large = 2   // 300+ 分钟

    static func from(minutes: Int) -> LycheeLevel {
        if minutes >= 300 { return .large }
        if minutes >= 60 { return .medium }
        return .small
    }

    var sizeMultiplier: CGFloat {
        switch self {
        case .small: return 1.0
        case .medium: return 1.15
        case .large: return 1.3
        }
    }

    var decoration: String? {
        switch self {
        case .small: return nil
        case .medium: return "sparkles"
        case .large: return "crown.fill"
        }
    }
}

/// 可复用的荔枝吉祥物视图
/// 支持多种动画状态、等级装饰、长按彩蛋
struct LycheeMascotView: View {
    let size: CGFloat
    var state: MascotState = .idle
    var level: LycheeLevel = .small
    var enableEasterEgg: Bool = true

    @State private var animationValue: CGFloat = 0
    @State private var showBubble = false
    @State private var bubbleText = ""
    @State private var bubbleTimer: Timer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 荔枝主体
            mascotImage
                .frame(width: actualSize, height: actualSize)
                .rotationEffect(.degrees(rotationAngle))
                .scaleEffect(scaleValue)
                .offset(y: offsetY)
                .animation(animationForState, value: state)

            // 等级装饰
            if let deco = level.decoration {
                Image(systemName: deco)
                    .font(.system(size: actualSize * 0.25))
                    .foregroundColor(level == .large ? .yellow : .accentColor)
                    .offset(x: actualSize * 0.15, y: -actualSize * 0.1)
                    .shadow(color: .yellow.opacity(0.5), radius: 3)
            }

            // 气泡（彩蛋 / Zzz）
            if showBubble {
                bubbleView
                    .offset(x: actualSize * 0.3, y: -actualSize * 0.4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { startAnimation() }
        .onChange(of: state) { _, _ in startAnimation() }
        .onLongPressGesture(minimumDuration: 0.5) {
            guard enableEasterEgg else { return }
            triggerEasterEgg()
        }
    }

    // MARK: - Private

    private var actualSize: CGFloat {
        size * level.sizeMultiplier
    }

    private var mascotImage: some View {
        Image("LycheeMascot")
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    // MARK: - Animation Parameters

    private var rotationAngle: CGFloat {
        switch state {
        case .listening:
            return animationValue * 5
        case .waving:
            return animationValue * 8
        case .surprised:
            return animationValue * 3
        case .sleeping:
            return -8
        default:
            return 0
        }
    }

    private var scaleValue: CGFloat {
        switch state {
        case .idle:
            return 1.0 + animationValue * 0.03
        case .thinking:
            return 1.0 + animationValue * 0.08
        case .happy:
            return 1.0 + abs(animationValue) * 0.15
        case .surprised:
            return 1.1 + abs(animationValue) * 0.1
        default:
            return 1.0
        }
    }

    private var offsetY: CGFloat {
        switch state {
        case .happy:
            return -abs(animationValue) * 8
        case .listening:
            return animationValue * 2
        default:
            return 0
        }
    }

    private var animationForState: Animation {
        switch state {
        case .idle:
            return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case .listening, .waving:
            return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        case .thinking:
            return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case .happy:
            return .spring(response: 0.3, dampingFraction: 0.5).repeatForever(autoreverses: true)
        case .surprised:
            return .easeInOut(duration: 0.15).repeatForever(autoreverses: true)
        case .sleeping:
            return .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
        }
    }

    private func startAnimation() {
        switch state {
        case .sleeping:
            showBubble = true
            bubbleText = "Zzz"
        default:
            showBubble = false
        }

        withAnimation(animationForState) {
            animationValue = 1.0
        }
    }

    // MARK: - Easter Egg

    private func triggerEasterEgg() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            showBubble = true
            bubbleText = "别挠了别挠了！"
        }

        bubbleTimer?.invalidate()
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                showBubble = false
            }
        }
    }

    // MARK: - Bubble View

    private var bubbleView: some View {
        Text(bubbleText)
            .font(.system(size: max(10, size * 0.22), weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            )
            .fixedSize()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 30) {
            LycheeMascotView(size: 60, state: .idle)
            LycheeMascotView(size: 60, state: .listening)
            LycheeMascotView(size: 60, state: .thinking)
        }
        HStack(spacing: 30) {
            LycheeMascotView(size: 60, state: .happy)
            LycheeMascotView(size: 60, state: .sleeping)
            LycheeMascotView(size: 60, state: .waving)
        }
        HStack(spacing: 30) {
            LycheeMascotView(size: 60, state: .surprised)
            LycheeMascotView(size: 60, level: .medium)
            LycheeMascotView(size: 60, level: .large)
        }
    }
}
