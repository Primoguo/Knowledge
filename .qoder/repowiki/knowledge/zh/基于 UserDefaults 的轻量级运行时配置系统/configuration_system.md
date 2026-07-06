## 1. 系统概览
本项目采用**纯 Swift + UserDefaults** 的轻量级运行时配置方案，没有引入第三方配置框架或外部配置文件。所有用户可编辑的配置（语音参数、主题、API Key、音色选择等）均以键值对形式持久化到 iOS 沙盒中；应用清单与构建期常量通过 Xcode 的 `Info.plist` 和 Scheme 变量注入。

## 2. 关键文件与职责
- `Resources/Info.plist`：应用元信息（Bundle ID、版本、后台音频模式等），由 Xcode 在打包时注入。
- `Models/VoiceConfig.swift`：定义语音合成配置结构体 `VoiceConfig` 及引擎枚举 `TTSEngine`，提供默认实例与常用语速预设。
- `ViewModels/SpeakerViewModel.swift`：作为配置 Facade，负责 `loadConfig()/saveConfig()` 将 `VoiceConfig` JSON 编码后写入 `UserDefaults.standard`，并在加载文档时自动检测语言并回写配置。
- `Views/APIKeyConfigView.swift`：提供阿里云 DashScope API Key 的输入 UI，读写 key `dashscope_api_key`。
- `Views/SettingsView.swift`：聚合外观、TTS 引擎、语速/音高/音量、语言与声音选择等设置项，修改后调用 `saveConfig()` 持久化。
- `Services/ThemeManager.swift`：以 `@Published` 暴露主题模式，写入 `themeMode` 键，供 SwiftUI 环境对象消费。
- `Models/ClonedVoice.swift`：`VoiceStore` 管理克隆音色列表、选中预设/克隆音色 ID，分别持久化为 `clonedVoices`、`selectedPresetVoiceId`、`selectedCloneVoiceId`。
- `Services/CosyVoiceService.swift` / `AISummaryService.swift`：构造时从 `UserDefaults` 读取 `dashscope_api_key`，用于请求鉴权。
- `ShareExtensionHandler.swift` & `ShareViewController.swift`：使用 `UserDefaults(suiteName: "group.com.voicereader.app")` 与主 App 共享配置。

## 3. 架构与约定
- **单一存储后端**：所有用户态配置均通过 `UserDefaults.standard` 存取，无独立配置服务层，读写散落在各模块内部。
- **JSON 序列化模型**：复合配置（如 `VoiceConfig`、`[ClonedVoice]`）通过 `JSONEncoder/Decoder` 整体编解码为 Data 再存入，避免字段级碎片化。
- **硬编码键名**：所有 UserDefaults key 均为字符串字面量（`voiceConfig`、`dashscope_api_key`、`themeMode`、`clonedVoices` 等），未集中声明，存在重复风险。
- **App Group 跨进程共享**：分享扩展与主 App 通过相同的 suite name 共享数据，但仅用于临时传递，核心配置仍各自维护本地副本。
- **构建期 vs 运行期分离**：`Info.plist` 承载不可变的应用清单；可变用户偏好全部走 UserDefaults，二者互不干扰。

## 4. 开发者应遵循的规则
1. **新增配置项**：优先复用现有 key 命名风格（小驼峰），若涉及复杂结构则定义 Codable 模型并通过 `JSONEncoder` 整体持久化。
2. **避免散落读取**：尽量将同一类配置的读写封装到对应 Model/Store 中（参考 `VoiceStore`），减少多处直接访问 `UserDefaults` 导致的键名不一致。
3. **敏感信息处理**：当前 API Key 明文存于 UserDefaults，生产环境建议迁移至 Keychain；如需环境变量注入，应在 Service 初始化处统一 fallback 逻辑。
4. **App Group 使用边界**：仅在 Share Extension ↔ 主 App 之间传递临时数据时使用 suite name，不要将其作为长期配置同步通道。
5. **向后兼容**：变更 UserDefaults key 或 VoiceConfig 字段时，需在 `loadConfig()` 中提供降级/迁移逻辑，避免旧版本用户数据损坏。