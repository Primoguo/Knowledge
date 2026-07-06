## 1. 采用的错误处理体系
- 错误类型定义：各服务模块使用 enum XxxError: LocalizedError 定义领域错误，通过 errorDescription 提供本地化文案。
- 传播方式：服务方法统一采用 throws / async throws 向上抛出错误，由调用方（ViewModel/View）决定是否消费或转交全局处理器。
- 全局展示层：Services/ErrorHandler.swift 提供 ErrorHandler.shared 单例，将错误转换为 SwiftUI AlertInfo 并通过 @Published currentAlert 通知 UI 弹窗；同时提供 log(level:) 分级打印日志。
- 异步安全：在后台线程调用 handle(_:context:) 时，通过 Task { @MainActor in ... } 切换回主线程更新 currentAlert，避免跨线程访问 ObservableObject。

## 2. 关键文件与包
- Services/ErrorHandler.swift — 全局错误处理单例、AlertInfo 结构体、LogLevel 枚举
- Services/AISummaryService.swift — AIServiceError（missingAPIKey / invalidAPIKey / invalidResponse / apiError / networkError）
- Services/CosyVoiceService.swift — CosyVoiceError（缺少 API Key、无效 Key、无音频数据、录音过短等）
- Services/TextExtractionService.swift — ExtractionError（不支持的文件类型、文件未找到、提取失败）
- Views/SummaryCardView.swift — SummaryErrorView（用于摘要场景的错误视图）
- App/KnowledgeApp.swift、Services/AudioSessionService.swift — 使用 do { try ... } catch 捕获系统级错误（ModelContainer、AudioSession）

## 3. 架构与约定
- 分层职责：Service 层只负责抛错（定义语义化错误类型），UI 层负责展示（通过 ErrorHandler.shared.handle(error, context:) 弹出 Alert）。
- 错误可本地化：所有自定义错误均遵循 LocalizedError，使 error.localizedDescription 可直接作为用户可读消息。
- 上下文标记：handle(_:context:) 支持传入 [context] 前缀，便于控制台快速定位出错模块。
- 日志级别：LogLevel.debug/info/warn/error 配合 emoji 前缀输出到控制台，便于开发调试。
- 无 panic/recover：代码中未发现 fatalError 或 defer recover，全部走可控的 throw/catch 路径。
- 无中间件：iOS 应用未引入网络/请求中间件，错误拦截发生在具体 Service 内部或调用处。

## 4. 开发者应遵守的规则
1. 新增错误必须实现 LocalizedError：为每个 .case 提供面向用户的 errorDescription，禁止直接暴露原始 NSError 给用户。
2. Service 方法签名：可能失败的接口一律声明 throws / async throws，不要吞掉异常返回可选值。
3. UI 层统一入口：需要向用户提示的错误，调用 ErrorHandler.shared.handle(error, context: moduleName)；仅需记录不弹窗的用 ErrorHandler.shared.log(..., level: .warn)。
4. 上下文信息：在 context 参数中写明当前模块名（如 "AISummaryService"），方便日志检索。
5. 避免在主线程阻塞：耗时错误处理逻辑放在 Task 中执行，仅 UI 更新切回 @MainActor。
6. 不要在 Service 内直接弹出 Alert：Service 应保持纯 Swift，UI 呈现由上层决定。