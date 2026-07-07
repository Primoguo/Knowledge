本项目采用最轻量的运行时配置方案：直接使用 `UserDefaults.standard` 作为唯一持久化后端，没有引入任何第三方配置库、配置文件或环境变量注入机制。所有用户可配置项（API Key、TTS 引擎与参数、主题模式、音色选择等）均以字符串键值形式散落在各模块中，由各自的服务/视图直接读写。

### 1. 使用的框架与工具
- **UserDefaults**：唯一的配置存储后端，用于持久化 API Key、语音合成参数、主题模式、克隆音色列表等。
- **Codable JSON 序列化**：复杂对象（如 `VoiceConfig`、`[ClonedVoice]`）通过 `JSONEncoder`/`JSONDecoder` 以 Data 形式存入 UserDefaults。
- **SwiftUI @Published + Combine**：`ThemeManager` 通过 `@Published` 暴露当前主题，并在 setter 中同步写入 UserDefaults，供 UI 实时响应。
- **单例服务**：`AISummaryService.shared`、`CosyVoiceService.shared`、`ThemeManager.shared` 在初始化时从 UserDefaults 读取所需配置。

### 2. 关键文件与包
- `Models/VoiceConfig.swift` — TTS 引擎类型枚举与语音配置结构体，定义默认值与常用语速预设。
- `Models/ClonedVoice.swift` — `VoiceStore` 静态类封装克隆音色列表与选中音色的 UserDefaults 存取。
- `Services/AISummaryService.swift` / `Services/CosyVoiceService.swift` — 在 `init()` 中直接从 `UserDefaults.standard.string(forKey: "dashscope_api_key")` 读取 API Key。
- `Services/ThemeManager.swift` — 单例 `ObservableObject`，将 `mode` 的 didSet 写入 UserDefaults key `themeMode`。
- `Views/APIKeyConfigView.swift` — 提供 API Key 输入界面，保存时写入 `dashscope_api_key`。
- `Views/SettingsView.swift` — 聚合所有语音设置，构造 `VoiceConfig` 后以 JSON 编码存入 `voiceConfig`。
- `ViewModels/SpeakerViewModel.swift` — 加载/保存 `voiceConfig`，并驱动 TTS 引擎切换。

### 3. 架构与约定
- **无集中配置入口**：不存在统一的 `Configuration` 类或配置文件加载器；每个需要配置的模块自行负责读取/写入对应的 UserDefaults key。
- **Key 命名约定**：使用简单字符串键名，如 `"dashscope_api_key"`、`"voiceConfig"`、`"themeMode"`、`"clonedVoices"`、`"selectedPresetVoiceId"`、`"selectedCloneVoiceId"`，未做统一常量管理。
- **分层职责**：
  - 视图层（`APIKeyConfigView`、`SettingsView`）负责收集用户输入并落盘。
  - 服务层（`AISummaryService`、`CosyVoiceService`）在构造时消费配置。
  - 模型层（`VoiceStore`）封装结构化数据的序列化和存取。
  - 管理器（`ThemeManager`）桥接 SwiftUI 状态与 UserDefaults。
- **运行时生效**：`ThemeManager` 和 `SpeakerViewModel` 在修改配置后即时更新内存状态，无需重启应用。

### 4. 开发者应遵循的规则
- **新增配置项**：直接在对应服务的 `init()` 中从 `UserDefaults.standard` 读取，或在视图保存时写入；若为复杂对象，优先使用 Codable + JSON 序列化。
- **避免硬编码 Key 字符串**：建议将 UserDefaults key 提取为集中常量（例如 `Keys.apiKey`），防止拼写不一致导致数据错乱。
- **敏感信息处理**：API Key 目前仅存于 UserDefaults，未使用 iOS Keychain；如需提升安全性，应迁移至 `SecItem`。
- **配置校验**：在服务入口处对必填配置（如 API Key）进行空值检查并抛出明确错误，已在 `AISummaryService` 和 `CosyVoiceService` 中体现。
- **向后兼容**：读取 UserDefaults 时应提供默认值（如 `?? ""` 或 `?? .defaultConfig`），避免因旧版本缺失 key 导致崩溃。
- **避免重复读写**：多个模块同时访问同一 key（如 `dashscope_api_key`）时，应确保写入原子性，必要时加锁或使用共享单例统一管理。