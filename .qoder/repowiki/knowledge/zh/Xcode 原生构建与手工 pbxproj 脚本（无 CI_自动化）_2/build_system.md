本仓库是一个纯 iOS SwiftUI 应用，采用 Xcode 工程（Knowledge.xcodeproj）作为唯一构建入口，未引入任何外部构建系统或 CI 流水线。具体特征如下：

1. 构建系统与工具链
- 使用 Xcode 原生项目文件 project.pbxproj 管理目标、依赖、资源与构建阶段。
- 通过 Swift Package Manager 的 workspace configuration 目录（project.xcworkspace/xcshareddata/swiftpm/configuration/）存在，但未见实际配置文件，推测仅保留空占位。
- 运行环境要求 iOS 17.0+、Xcode 15+，需在 Signing & Capabilities 中手动启用 Background Modes → Audio。
- 未配置 Makefile、fastlane、xcbuild cache、CI（GitHub Actions / Bitrise 等）、Dockerfile 或任何自动化脚本。

2. 关键构建相关工件
- Knowledge.xcodeproj/project.pbxproj：核心构建描述文件，包含 Target、Build Phases、Resources、Info.plist 引用等。
- Resources/Assets.xcassets、Resources/Info.plist：打包时由 Xcode 注入的二进制资源清单。
- ShareExtension/Info.plist + ShareViewController.swift：Share Extension 子目标，独立 Bundle ID，需单独签名与分发。
- App/KnowledgeApp.swift + AppDelegate.swift：SwiftUI 应用入口与后台音频会话初始化点。

3. 手工 pbxproj 修补脚本
仓库根目录提供三套 Python 脚本，用于在本地将另一个同名工程 VoiceReader 迁移到当前 Knowledge 工程：
- copy_ppbj.py：从固定临时路径复制 pbxproj 到目标路径。
- fix_pbpj.py / modify_pbpj.py：对 pbxproj 执行字符串级替换——将 com.voicereader.app 改为 com.knowledge.app、VoiceReader 改为 Knowledge；删除 EdgeTTSService 的 PBXBuildFile/PBXFileReference/group 引用；插入 Assets.xcassets 的 FileReference、BuildFile 及 Resources Build Phase 条目。
这些脚本硬编码了绝对路径（/Users/primo/CodeBuddy/阅读器/VoiceReader/...），不具备可移植性，属于一次性迁移辅助工具，不应纳入正式构建流程。

4. 版本与发布策略
- 未发现 Info.plist 中的 CFBundleShortVersionString / CFBundleVersion 更新脚本或约定。
- 未发现 .gitignore 中排除 xcuserdata、xcshareddata 以外的构建产物规则（默认已忽略 DerivedData、*.xcarchive 等）。
- 未集成 TestFlight / App Store Connect / fastlane match 等发布通道。

5. 开发者应遵循的规则
- 所有构建与调试均在 Xcode 内完成，不要自行编写 Makefile 或 shell 构建脚本。
- 新增源文件或资源后，务必在 Xcode 中添加到对应 Target 的 Sources/Resources Build Phase，避免直接编辑 pbxproj。
- 如需批量修改工程元数据，优先使用 Xcode 提供的 Project Navigator 操作，而非手写正则替换 pbxproj。
- 若未来引入自动化，建议以 xcodebuild + fastlane 替代手工 Python 脚本，并统一在 CI 中执行。
- Share Extension 需单独配置 Bundle ID 与签名证书，注意与主 App 共享 App Group 时的权限声明。