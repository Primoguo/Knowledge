本仓库是一个纯 iOS SwiftUI 应用，未使用任何第三方依赖管理工具。项目完全基于 Apple 生态的原生能力构建，所有功能均通过系统框架实现。

## 依赖声明方式
- 无 Package.swift：未使用 Swift Package Manager (SPM)
- 无 Podfile/Cartfile：未使用 CocoaPods 或 Carthage
- 无 vendor/ 目录：未 vendoring 第三方源码
- 无 lockfile：无 Package.resolved、Podfile.lock 等锁定文件

## 实际依赖来源
项目仅依赖以下系统框架（在 Xcode 中通过 Link Binary With Libraries 配置）：
- SwiftUI：声明式 UI 框架
- SwiftData：数据持久化
- AVFoundation：语音合成（AVSpeechSynthesizer）、音频播放
- UIKit：文件选择器（UIDocumentPickerViewController）
- Foundation：基础类型与网络请求
- MPNowPlayingInfoCenter：锁屏信息与控制中心集成

## 外部服务集成
虽然不引入第三方 SDK，但代码直接通过 HTTP 调用外部 API：
- 阿里云 DashScope API：AI 摘要生成（AISummaryService.swift）
- CosyVoice 语音合成服务：AI 语音合成（CosyVoiceService.swift、CosyVoiceSynthesizer.swift）
- 语言检测服务：文本语言识别（LanguageDetector.swift）
这些 API 调用通过原生 URLSession 实现，无需额外依赖库。

## 架构约定
- 所有业务逻辑封装在 Services/ 目录下，便于替换实现
- 通过协议抽象（如 SpeechSynthesizerProtocol）支持多实现切换
- 运行时配置通过 UserDefaults 管理 API Key 等敏感信息

## 开发者注意事项
1. 新增第三方依赖时建议优先评估是否可用系统框架替代
2. 若必须引入三方库，推荐使用 SPM 并统一在根级 Package.swift 管理
3. 当前项目规模较小，手动维护依赖成本可控；随着复杂度增长应引入正式依赖管理工具