# 挠荔枝（Knowledge）

一款 iOS 有声阅读器，让你用耳朵"阅读"文档。导入 PDF、Word、Excel、PPT 或 TXT 文件，即可通过语音朗读功能在后台播放，像听音乐一样听书。

## 功能特性

| 功能 | 说明 |
|------|------|
| 📥 **文档导入** | 支持 PDF、TXT、Word（.doc/.docx）、Excel（.xls/.xlsx）、PPT（.ppt/.pptx） |
| 🔊 **语音朗读** | 基于系统 AVSpeechSynthesizer，无需联网，支持多种语言 |
| 🎛️ **后台播放** | 切换 App 后继续朗读，锁屏状态显示播放控制 |
| ⚙️ **语音设置** | 可调节语速、音高、音量，切换语言与声音 |
| 📍 **进度记忆** | 自动保存朗读位置，下次打开继续播放 |
| 📚 **书库管理** | 支持删除、查看文档，显示朗读进度 |

## 技术栈

- **SwiftUI + UIKit 混合** — 现代声明式 UI + 文件选择器
- **MVVM 架构** — 清晰的业务逻辑分离
- **SwiftData** — 文档数据持久化
- **AVSpeechSynthesizer** — 系统语音合成
- **MPNowPlayingInfoCenter** — 锁屏信息与控制中心

## 项目结构

```
Knowledge/
├── App/
│   ├── KnowledgeApp.swift      # 应用入口
│   └── AppDelegate.swift          # 后台音频配置
├── Models/
│   ├── Document.swift               # 文档数据模型
│   ├── PlaybackState.swift          # 播放状态
│   └── VoiceConfig.swift            # 语音配置
├── ViewModels/
│   └── SpeakerViewModel.swift     # 核心播放逻辑
├── Services/
│   ├── SpeechService.swift          # 语音合成服务
│   ├── TextExtractionService.swift  # 文本提取服务
│   ├── NowPlayingService.swift      # 锁屏控制服务
│   └── AudioSessionService.swift    # 音频会话管理
├── Views/
│   ├── ContentView.swift            # 主界面
│   ├── DocumentListView.swift       # 文档列表
│   ├── DocumentRowView.swift        # 文档行
│   ├── PlayerView.swift             # 播放器界面
│   ├── PlayerControlsView.swift     # 播放控制
│   └── SettingsView.swift           # 设置界面
├── UIKit/
│   └── DocumentPicker.swift         # 文件选择器
└── Resources/
    └── Info.plist                   # 应用配置
```

## 运行要求

- **iOS 17.0+**
- **Xcode 15+**
- 在 **Signing & Capabilities** 中启用 **Background Modes → Audio**

## 使用方式

1. 打开书库，点击右上角 **+** 导入文档
2. 选择要朗读的文档，点击播放按钮
3. 在播放器界面控制播放/暂停、快进/快退
4. 在设置页调整语速、音高、音量、语言
5. 切换其他 App 或锁屏，朗读继续后台播放

## 截图

> 待补充

## 许可证

MIT License
