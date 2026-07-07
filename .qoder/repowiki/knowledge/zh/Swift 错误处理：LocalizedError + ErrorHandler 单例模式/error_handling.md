本仓库采用 Swift 标准 async/throws 错误传播机制，结合 LocalizedError 协议与全局 ErrorHandler 单例，形成领域错误枚举到调用层捕获再到统一弹窗提示的分层处理体系。

## 1. 系统与方法
- 错误定义：各服务模块在文件末尾以 enum XxxError: LocalizedError 形式声明领域错误，通过 errorDescription 提供用户可读的中文描述。
- 错误传播：所有对外 API 使用 async throws 向上抛出，不吞掉错误；上层（ViewModel / View）用 do { try await } catch 捕获。
- 统一呈现：Services/ErrorHandler.swift 提供 ErrorHandler.shared.handle(_:context:)，将错误转为 AlertInfo 并通过 @Published currentAlert 驱动 SwiftUI Alert 弹窗；同时提供 log(_:level:) 仅打印日志。
- 日志级别：LogLevel.debug/info/warn/error 配合 emoji 前缀，全部走 print，无第三方日志框架。

## 2. 关键文件与包
- Services/ErrorHandler.swift — 全局错误处理单例、Alert 数据模型、日志方法
- Services/AISummaryService.swift — AIServiceError 枚举（missingAPIKey / invalidAPIKey / invalidResponse / apiError / networkError）
- Services/CosyVoiceService.swift — CosyVoiceError 枚举（缺少 audioTooShort/noAudioData 等语音域错误）
- Services/CompanionService.swift — 复用 AIServiceError
- Views/ContentView.swift、Views/DocumentListView.swift、Views/VoiceCloneView.swift、Views/VoiceSelectView.swift — 典型 catch 处直接读取 error.localizedDescription 展示
- Services/AudioSessionService.swift、UIKit/DocumentPicker.swift、Services/CosyVoiceSynthesizer.swift、Services/TextExtractionService.swift — 对系统 API 的 do/catch 仅 print 记录

## 3. 架构与约定
- 分层职责：Service 层负责把底层异常（网络、JSON 解析、HTTP 状态码）映射为语义化的 XxxError 并 throw。ViewModel / View 层 try await 调用后 catch，优先调用 ErrorHandler.shared.handle(error, context:)；若上下文无关则直接用 error.localizedDescription 弹窗。
- 错误可本地化：所有业务错误均实现 LocalizedError.errorDescription，保证 error.localizedDescription 始终返回中文提示，简化 UI 层逻辑。
- 无 panic/recover：全仓未见 fatalError、preconditionFailure 或 defer recover，崩溃场景未显式兜底。
- 无中间件/拦截器：iOS 应用形态，错误处理集中在调用点，不存在服务端式的中间件链。

## 4. 开发者应遵循的规则
1. 新增错误先定义枚举：在对应 Service 文件末尾追加 enum XxxError: LocalizedError 分支，并在 errorDescription 中给出面向用户的中文文案。
2. 不要吞掉错误：Service 内部只负责转换和 throw，禁止 do { ... } catch { print(...) } 静默失败。
3. UI 层统一入口：捕获后优先 ErrorHandler.shared.handle(error, context: "模块名")，让日志前缀与弹窗文案保持一致。
4. 系统 API 降级策略：对 AVAudioSession、UIDocumentPicker 等系统调用，如无法恢复，允许 catch 后 print 记录并继续运行，但需附带清晰的前缀标识。
5. 避免在 View 内抛错：View 不应再向上传播错误，应在自身作用域内完成 catch 与提示。