本项目为 iOS SwiftUI 应用，前端样式完全基于 SwiftUI 原生能力实现，未引入任何第三方 UI 框架或 CSS 方案。整体风格围绕「系统自适应 + 自定义强调色」构建，核心设计决策如下：

1. **颜色体系**
- 全局强调色通过 `Resources/Assets.xcassets/AccentColor.colorset` 定义，采用 sRGB 空间、固定 RGB 值（红 0 / 绿 0.584 / 蓝 1），并在 light/dark 两套外观下保持一致。
- 其余色彩全部使用 SwiftUI 语义化颜色（`.primary`、`.secondary`、`.systemBackground`、`.systemGray6`、`.white`、`.gray` 等），不硬编码具体色值，从而自动适配深色模式。
- 强调色通过 `.tint(.accentColor)` 在根视图设置，配合 `.foregroundColor(.accentColor)`、`.background(Color.accentColor.opacity(0.1))` 等修饰符统一点缀交互元素。

2. **字体排版**
- 遵循 Apple 文案层级：`.largeTitle` → `.title` → `.headline` → `.subheadline` → `.body` → `.caption` → `.caption2`，仅在需要精确控制时回退到 `.system(size:)`。
- 代码片段类文本使用等宽字体 `.font(.system(.body, design: .monospaced))`。
- 字重仅使用 `.semibold` 作为强调，其余依赖系统默认字重。

3. **间距与圆角**
- 内边距以 6/8/12/16 的 4pt 倍数为主，形成统一的节奏；外边距较少使用，主要依赖 VStack/HStack 的 `spacing`。
- 卡片/气泡圆角集中在 14–16pt 区间，保持柔和一致的视觉语言。

4. **主题切换机制**
- `Models/ThemeMode.swift` 枚举三种模式（跟随系统/白天/暗黑），并提供 `ColorScheme?` 映射。
- `Services/ThemeManager.swift` 作为 `ObservableObject` 单例，将当前模式写入 `UserDefaults`，并通过 `@Published` 驱动 UI 刷新。
- 根应用 `App/KnowledgeApp.swift` 在 `WindowGroup` 上调用 `.preferredColorScheme(themeManager.mode.colorScheme)` 并注入 `environmentObject(themeManager)`，使全树视图可响应主题变化。

5. **图标与资源**
- SF Symbols 作为唯一图标来源，通过 `Image(systemName:)` 引用，无需额外图片资源。
- App Icon 及 Accent Color 均通过 Assets Catalog 管理，支持多分辨率与外观变体。

6. **无独立样式层**
- 项目不存在 CSS/SCSS/Tailwind 等外部样式文件，所有视觉表现均在 SwiftUI 视图链中通过修饰符组合完成。
- 未定义自定义 ViewModifier 或 Style 协议扩展，样式逻辑直接内联于各 View 中。

开发者应遵循的约定：
- 新增颜色一律走 Assets Catalog 的 AccentColor 或系统语义色，禁止在视图里写死十六进制色值。
- 字体优先使用 Apple 文案层级名称，仅在特殊场景才用 `.system(size:)`。
- 主题相关状态统一经 `ThemeManager.shared` 读写，不要绕过 UserDefaults 持久化。
- 间距与圆角尽量复用现有 4pt 倍数的数值，避免随意取值破坏视觉一致性。