本仓库未引入任何第三方或系统级日志框架（如 os.log、Logger），而是采用最轻量的方式：以 `print` 作为唯一输出通道，并通过一个全局单例 `ErrorHandler` 提供统一的日志前缀与级别标记。

- **核心实现**：`Services/ErrorHandler.swift` 定义了 `LogLevel`（debug/info/warn/error）和 `ErrorHandler.shared`，其中 `log(_:level:)` 仅做带 emoji 前缀的 `print`；`handle(_:context:)` 在打印的同时通过 `@Published currentAlert` 向 SwiftUI 弹出用户提示。
- **使用范围**：目前仅在 `LanguageDetector.swift` 中调用 `ErrorHandler.shared.log(...)` 记录语言检测过程；其余模块（AudioSessionService、TextExtractionService、SpeakerViewModel、DocumentPicker 等）直接散落 `print` 语句，没有统一入口。
- **日志级别策略**：虽然定义了 debug/info/warn/error 四级，但所有级别最终都走同一 `print` 输出，无过滤、无结构化字段、无持久化或远程上报能力。
- **架构约定**：尚未形成强制规范——部分代码用 `ErrorHandler.shared.log`，更多代码直接用 `print`，两者并存。