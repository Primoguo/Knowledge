本仓库未引入任何第三方日志框架，也未使用 os_log/Logger 等系统结构化日志 API。整个应用的输出全部通过标准库 print() 完成，并围绕一个全局单例 ErrorHandler 提供统一的日志前缀与错误弹窗能力。

核心机制
- ErrorHandler.shared：全局单例，暴露两个方法
  - handle(_:context:)：将 Error 转为本地化消息，用 ❌ 前缀打印，并通过 @Published currentAlert 触发 UI 弹窗。
  - log(_:level:)：按 LogLevel.debug/info/warn/error 选择 emoji 前缀后直接 print。
- LogLevel 枚举仅用于区分前缀，不控制输出开关；所有级别均会输出到控制台。
- 调用方直接使用 ErrorHandler.shared.log(...) 或 ErrorHandler.shared.handle(error, context: "...")，无需注入依赖。

分布情况
- 日志散落在各模块中：Services（AudioSessionService、TextExtractionService、LanguageDetector）、UIKit、ViewModels 等处均有裸 print 调用，风格统一为“emoji + 中文描述”的一行式输出。
- 没有集中化的日志初始化、sink 配置、文件落盘或远程上报逻辑。

设计取舍
- 优点：零依赖、实现极简，适合小型 iOS 应用快速调试。
- 缺点：无结构化字段、无法按环境过滤、无法持久化，难以在复杂项目中定位问题。

开发者约定
- 优先使用 ErrorHandler.shared.log(message, level: .info|warn|error) 替代裸 print，保持前缀一致。
- 需要向用户展示的错误统一走 handle(_:context:)，由 ErrorHandler 负责弹窗。
- 如需新增日志级别或 sink，应在 ErrorHandler 内扩展，避免在各处重复实现。