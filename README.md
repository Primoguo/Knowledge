# 挠荔枝（Knowledge）

一款 AI 驱动的 iOS 有声阅读器，让你用耳朵"阅读"文档。导入 PDF、Word、Excel、PPT、EPUB 或 TXT 文件，即可通过高品质语音朗读在后台播放，像听音乐一样听书。内置 AI 总结与 AI 伴读，帮你快速理解和深度消化文档内容。

## 功能特性

| 功能 | 说明 |
|------|------|
| 📥 **文档导入** | 支持 PDF、TXT、Word、Excel、PPT、EPUB，支持网页链接导入，支持系统分享菜单 |
| 🔊 **多引擎语音** | 三引擎可选：Apple Neural TTS（系统推荐）、Edge TTS（微软云端免费高品质）、CosyVoice（AI 音色克隆） |
| 🎧 **后台播放** | 切换 App 后继续朗读，锁屏状态显示播放控制，支持控制中心操控 |
| 📝 **AI 总结** | 一键生成文档摘要，支持简版/详版两种模式，结果自动缓存 |
| 💬 **AI 伴读** | 边听边问的多轮对话，基于朗读上下文智能回答，支持入门/进阶/专业三种难度 |
| 📍 **进度记忆** | 自动保存朗读位置，下次打开继续播放 |
| 📚 **书库管理** | 文档列表 + 继续收听快捷入口，支持删除与进度查看 |
| 🎨 **Notion 风格** | 极简黑白灰设计语言，支持跟随系统/白天/暗黑三种主题 |
| 🔁 **循环播放** | 播放结束后自动从头开始 |
| 💾 **对话持久化** | AI 伴读记录按文档独立存储，切换/重启自动恢复 |
| 🧑‍🎤 **音色克隆** | CosyVoice 引擎支持上传音频克隆个人音色（即将推出） |
| 💎 **Premium 订阅** | StoreKit 内购，免费用户可体验 AI 总结/伴读各 1 次 |

## 技术栈

| 技术 | 用途 |
|------|------|
| **SwiftUI + UIKit** | 声明式 UI + 文件选择器桥接 |
| **MVVM** | 清晰的业务逻辑分离 |
| **SwiftData** | 文档元数据 + 对话记录持久化 |
| **AVFoundation** | 系统语音合成 + 音频播放 |
| **StoreKit 2** | 订阅内购与恢复购买 |
| **MPNowPlayingInfoCenter** | 锁屏信息与控制中心 |
| **自建服务器中转** | naolizhi.cn — Edge TTS 合成 + DeepSeek AI 问答 |

## 项目结构

```
Knowledge/
├── App/
│   ├── KnowledgeApp.swift           # 应用入口 + SwiftData 配置
│   └── AppDelegate.swift            # 后台音频配置
├── Models/
│   ├── Document.swift               # 文档数据模型（SwiftData）
│   ├── PlaybackState.swift          # 播放状态枚举
│   ├── ThemeMode.swift              # 主题模式
│   ├── VoiceConfig.swift            # 语音配置（引擎/音色/参数）
│   ├── CompanionMessage.swift       # 伴读消息模型
│   ├── CompanionChat.swift          # 对话持久化模型（SwiftData）
│   ├── SummaryResult.swift          # AI 摘要结果模型
│   ├── ClonedVoice.swift            # 克隆音色数据
│   └── LycheeLevelManager.swift     # 荔枝角色等级系统
├── ViewModels/
│   └── SpeakerViewModel.swift       # 核心播放 + AI 功能调度
├── Services/
│   ├── SpeechService.swift          # 语音合成服务（协议层）
│   ├── EdgeTTSService.swift         # Edge TTS 云端合成
│   ├── EdgeTTSSynthesizer.swift     # Edge TTS 引擎适配器
│   ├── CosyVoiceService.swift       # CosyVoice AI 音色服务
│   ├── CosyVoiceSynthesizer.swift   # CosyVoice 引擎适配器
│   ├── CompanionService.swift       # AI 伴读服务（DeepSeek）
│   ├── AISummaryService.swift       # AI 摘要服务（DeepSeek）
│   ├── TextExtractionService.swift  # 文本提取（PDF/Office/网页）
│   ├── NowPlayingService.swift      # 锁屏控制
│   ├── AudioSessionService.swift    # 音频会话管理
│   ├── SubscriptionManager.swift    # StoreKit 订阅管理
│   ├── SystemVoiceManager.swift     # 系统音色管理
│   ├── LanguageDetector.swift       # 语言检测
│   ├── ThemeManager.swift           # 主题管理
│   ├── ErrorHandler.swift           # 全局错误处理
│   ├── ShareExtensionHandler.swift  # 分享内容处理
│   └── ServerAPIClient.swift        # 服务器 API 客户端
├── Views/
│   ├── ContentView.swift            # 主界面（TabView）
│   ├── DocumentListView.swift       # 书库列表
│   ├── DocumentRowView.swift        # 文档卡片
│   ├── PlayerView.swift             # 播放器界面
│   ├── PlayerControlsView.swift     # 播放控件
│   ├── SummaryCardView.swift        # AI 摘要卡片
│   ├── CompanionView.swift          # AI 伴读对话
│   ├── SettingsView.swift           # 设置界面
│   ├── PaywallView.swift            # 付费墙
│   ├── VoiceSelectView.swift        # CosyVoice 音色选择
│   ├── SystemVoiceSelectView.swift  # 系统音色选择
│   ├── VoiceCloneView.swift         # 音色克隆界面
│   └── APIKeyConfigView.swift       # API 配置
├── UIKit/
│   └── DocumentPicker.swift         # 文件选择器桥接
├── ShareExtension/
│   └── ShareViewController.swift    # 系统分享扩展
└── Resources/
    ├── Assets.xcassets              # 图标与颜色资源
    └── Info.plist                   # 应用配置
```

## 运行要求

- **iOS 17.0+**
- **Xcode 16+**
- 在 **Signing & Capabilities** 中启用 **Background Modes → Audio**

## 使用方式

1. 打开书库，点击右上角 **+** 导入文档（或通过系统分享菜单发送文件到 App）
2. 选择要朗读的文档，进入播放器
3. 控制播放/暂停、快进/快退，调节语速
4. 点击 **AI 总结** 一键生成文档摘要
5. 点击 **AI 伴读** 边听边问，深度理解文档
6. 在设置页切换语音引擎、调节音色参数、选择主题

## 架构说明

```
用户导入文档
    ↓
TextExtractionService（PDF/Office/网页 → 纯文本）
    ↓
SpeakerViewModel（播放控制 + AI 调度）
    ├── SpeechService → Edge TTS / System TTS / CosyVoice
    ├── AISummaryService → naolizhi.cn → DeepSeek
    └── CompanionService → naolizhi.cn → DeepSeek
```

语音合成支持段落预加载实现无缝衔接，Edge TTS 本地磁盘缓存减少重复请求。

## 相关链接

- 官网：[naolizhi.cn](https://naolizhi.cn)
- 隐私政策：[naolizhi.cn/privacy.html](https://naolizhi.cn/privacy.html)

## 许可证

MIT License
