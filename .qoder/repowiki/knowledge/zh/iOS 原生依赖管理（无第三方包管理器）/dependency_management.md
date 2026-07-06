本仓库是一个纯 Swift/iOS 项目，**未使用任何第三方依赖管理系统**。所有依赖均为 Apple 平台框架，通过 Xcode 工程直接链接，不存在以下文件与机制：
- 无 `Package.swift` / `swift-tools-version`（未启用 SwiftPM）
- 无 `Podfile` / `Cartfile` / `Project.pbxproj` 中外部 SPM 引用
- 无 `go.mod`、`package.json`、`requirements.txt` 等非 iOS 语言清单
- 无 `vendor/`、`Pods/`、`Carthage/Build/` 等 vendored 目录
- 无 `.gitignore` 中对第三方缓存的忽略规则

代码中的 `import` 全部指向系统框架：`Foundation`、`SwiftUI`、`SwiftData`、`AVFoundation`、`Combine`、`MediaPlayer`、`PDFKit`、`UIKit`。这些框架由 Xcode 随 SDK 提供，无需额外声明版本或锁定。

唯一的“依赖”是 Xcode 工程文件 `Knowledge.xcodeproj/project.pbxproj`，它隐式绑定了目标 iOS SDK 版本及上述系统框架。任务报告中也明确提到“无 Xcode 项目文件 — 需要在 Xcode 中手动创建或使用 `swift package generate-xcodeproj`”，说明该项目当前处于最小化状态，尚未引入任何第三方库。

结论：本项目在当前阶段**不涉及第三方依赖管理**，该分类对本仓库不适用。