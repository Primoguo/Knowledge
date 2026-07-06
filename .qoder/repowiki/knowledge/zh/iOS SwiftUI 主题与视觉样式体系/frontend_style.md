本项目为纯 iOS 原生应用，采用 SwiftUI 作为 UI 框架，未使用任何 CSS/SCSS/Tailwind 等 Web 样式技术。前端风格由以下机制构成：

1. **主题模式**：通过 `Models/ThemeMode.swift` 定义 `system/light/dark` 三种模式，并映射到 SwiftUI 的 `ColorScheme`；图标名称、显示文案均内聚于枚举。
2. **主题状态管理**：`Services/ThemeManager.swift` 以单例 `ObservableObject` 形式暴露 `@Published var mode`，启动时从 `UserDefaults` 恢复上次选择，并在设置页提供切换按钮。
3. **全局注入**：在 `App/KnowledgeApp.swift` 中通过 `.environmentObject(themeManager)` 将主题管理器注入环境，并使用 `.preferredColorScheme(themeManager.mode.colorScheme)` 强制覆盖系统配色。
4. **设计资源**：`Resources/Assets.xcassets/AccentColor.colorset/Contents.json` 定义了应用的强调色（sRGB），同时配置了 dark appearance 变体，供 SwiftUI 自动按明暗模式选取。
5. **视图层约定**：所有界面组件均为 SwiftUI View，无自定义 UIKit 样式或第三方 UI 库引用，颜色与字体依赖系统语义化资源（如 SF Symbols）与 AccentColor。

整体遵循「单一来源 + 环境传播」的轻量主题方案，未引入独立的设计令牌文件或跨平台样式抽象。