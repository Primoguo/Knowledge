本项目采用纯 Xcode 原生构建体系，未引入任何第三方构建工具或 CI 流水线。核心构建产物由 `Knowledge.xcodeproj` 中的 `project.pbxproj` 描述，通过共享 Scheme `Knowledge.xcscheme` 统一指定 Build/Test/Profile/Analyze/Archive 行为，目标产物为 `Knowledge.app`。

项目同时维护了三个 Python 辅助脚本用于在仓库间迁移和修补 pbxproj：
- `copy_ppbj.py`：从临时路径复制生成的 pbxproj 到目标工程目录；
- `fix_ppbj.py` / `modify_ppbj.py`：通过字符串替换与正则表达式对 pbxproj 执行重命名（VoiceReader → Knowledge、bundle ID 变更）、删除废弃文件引用（EdgeTTSService.swift）、注入 Assets.xcassets 引用等手工操作。
这些脚本直接硬编码绝对路径（如 `/Users/primo/CodeBuddy/阅读器/VoiceReader/...`），表明它们仅服务于本地开发时的跨仓库迁移场景，不具备可移植性。

关键约束与约定：
- 运行环境要求 iOS 17.0+、Xcode 15+，需在 Signing & Capabilities 中手动启用 Background Modes → Audio；
- 未使用 Swift Package Manager、CocoaPods、Carthage 等依赖管理工具，所有依赖均通过 Xcode 原生 Target 链接；
- 未发现 Makefile、Dockerfile、GitHub Actions、Fastlane、xcpretty、gym 等 CI/打包脚本，发布流程完全依赖 Xcode Organizer 手动 Archive；
- Scheme 中 TestAction 的 Testables 为空，项目未集成单元测试目标。