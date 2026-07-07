# Knowledge（挠荔枝）产品需求文档

---

## 1. 文档概览

| 项目 | 内容 |
|------|------|
| 版本号 | V1.4.0 |
| 状态 | 已生效（持续迭代中） |
| 创建日期 | 2026-07-05 |
| 作者 | Primoguo |
| 产品名称 | Knowledge / 挠荔枝 |
| 平台 | iOS 17+（SwiftUI + SwiftData） |
| 代码仓库 | https://github.com/Primoguo/Knowledge |

---

## 2. 修订记录

| 版本 | 日期 | 修改人 | 修改内容 |
|------|------|--------|----------|
| V1.0 | 2026-07-05 | AI Agent | 初始版本，基于现有代码整理 |
| V1.1 | 2026-07-05 | AI Agent | 补充三大待开发功能规划 |
| V1.2 | 2026-07-05 | AI Agent | 移除 Edge TTS 引擎（不可用），后续 TTS 统一使用阿里云 CosyVoice |
| V1.3 | 2026-07-05 | AI Agent | 新增主题模式功能（跟随系统/白天/暗黑）；项目重命名为 Knowledge；添加 Assets.xcassets |
| V1.4 | 2026-07-06 | AI Agent | 新增 AI 伴读功能（预埋，默认隐藏）：边听边问的交互式多轮对话，基于通义千问，携带朗读上下文 |

---

## 3. 背景与目标

### 3.1 业务背景

信息爆炸时代，用户每天面对大量文字内容——PDF 报告、电子书、网页文章、Office 文档。传统阅读方式受限于场景（通勤、运动、做家务时无法阅读）和视力疲劳。Knowledge 致力于**让用户用耳朵「阅读」一切文字内容**，将任意文档格式转为高品质有声朗读。

### 3.2 产品目标（SMART）

| 目标 | 指标 | 当前状态 |
|------|------|----------|
| **多格式支持** | 支持 PDF/EPUB/DOCX/XLSX/PPTX/MD/TXT/网页 8 种格式 | ✅ 已实现 |
| **自然语音体验** | 提供系统 TTS，后续接入阿里云 CosyVoice 高品质语音 | ✅ 系统 TTS（离线可用） |
| **网页正文识别** | 自动过滤导航/广告/推荐，提取正文准确率 ≥ 90% | ✅ 已实现 |
| **主题模式** | 支持跟随系统、白天、暗黑三种外观模式 | ✅ 已实现 |
| **AI 伴读** | 边听边问，基于当前朗读位置上下文的多轮对话 | ✅ 已预埋（默认隐藏） |
| **AI 智能总结** | 用户导入文档后一键获取 AI 摘要 | 🔲 待开发 |
| **个性化音色** | 用户可录制声音并克隆为自己的朗读音色 | 🔲 待开发 |
| **AI 播客** | 文档/网页一键转为双人对话播客音频 | 🔲 待开发 |

### 3.3 用户画像

| 角色 | 核心诉求 | 典型场景 |
|------|---------|----------|
| **知识工作者** | 通勤路上「阅读」行业报告/长文 | 地铁上听华尔街见闻文章 |
| **学生/研究者** | 将 PDF 论文/教材转为音频复习 | 运动时听课程资料 |
| **阅读爱好者** | EPUB 电子书转有声书 | 睡前听书 |
| **内容创作者** | 将文章一键转为播客内容 | 把公众号文章做成播客分发 |
| **视障/阅读障碍用户** | 无障碍获取文字信息 | 日常信息获取 |

---

## 4. 范围定义

### 4.1 包含范围（In Scope）— 已实现

| 功能模块 | 说明 | 版本 |
|---------|------|------|
| **文档导入** | 文件选择器（PDF/EPUB/DOCX/XLSX/PPTX/TXT/MD） + 网页链接输入 | V1.0 |
| **Share Extension** | Safari 分享菜单一键导入网页 | V1.0 |
| **文本提取** | 多格式解析引擎（PDF OCR 回退、EPUB ZIP 解压、Office 解析、网页正文定位） | V1.0-V1.2 |
| **书库管理** | SwiftData 持久化、最近打开排序、收藏、滑动删除 | V1.0 |
| **系统 TTS 引擎** | 基于 AVSpeechSynthesizer，500 字分块，支持 18 种语言自动检测 | V1.0 |
| **播放控制** | 播放/暂停、快进 30s、快退 15s、5 档快捷语速 | V1.0 |
| **阅读高亮** | 当前朗读位置高亮 + 加粗 + 背景色标记 | V1.0 |
| **锁屏控制** | Now Playing 信息展示 + 远程播放控制 | V1.0 |
| **主题模式** | 跟随系统 / 白天 / 暗黑三种外观，设置页一键切换，UserDefaults 持久化 | V1.3 |
| **AI 伴读** | 边听边问，基于朗读上下文的多轮对话，通义千问驱动 | V1.4 |
| **设置管理** | 引擎选择、语速/音高/音量调节、语言/语音选择、8 档语速预设 | V1.0-V1.2 |

### 4.2 不包含范围（Out of Scope）

| 内容 | 原因 |
|------|------|
| 视频/音频文件导入 | 非文字内容，超出「阅读器」定位 |
| 实时网页爬取 | 技术复杂度高，法律风险 |
| 社交分享/评论 | 当前定位为工具型产品 |
| 云端同步书库 | 需后端支持，当前无服务端 |

### 4.3 MVP 边界（MoSCoW）

| 优先级 | 内容 | 状态 |
|--------|------|------|
| **Must** | 多格式导入、文本提取、TTS 朗读、播放控制、书库管理 | ✅ 已完成 |
| **Should** | 网页正文识别、锁屏控制、主题模式、AI 伴读 | ✅ 已完成 |
| **Could** | 更多格式支持、更多语言语音 | 部分完成 |
| **Won't（本期）** | AI 总结、语音克隆、AI 播客、阿里云 CosyVoice TTS 引擎 | 🔲 下期 |

---

## 5. 价值主张

### 5.1 核心价值主张

> **「把任何文字变成听得见的知识」**

| 维度 | 现状（Before） | 解决方案（How） | 改变后（After） |
|------|---------------|----------------|----------------|
| **场景受限** | 只能在屏幕前阅读 | 任意场景语音播放 | 通勤/运动/做家务都能「阅读」 |
| **格式碎片** | 不同格式用不同 App 打开 | 统一导入，一键朗读 | 一个 App 搞定所有文字内容 |
| **语音生硬** | 系统 TTS 音质一般 | 后续接入 CosyVoice AI 语音 | 接近真人朗读的自然体验 |
| **网页噪音** | 朗读时读导航/广告/推荐 | 智能正文提取 + 后处理清洗 | 只读有用的内容 |
| **暗光阅读** | 夜间屏幕刺眼 | 暗黑模式 + 跟随系统 | 全天候舒适阅读 |

### 5.2 替代方案（Alternatives）

| 替代方案 | 劣势 |
|----------|------|
| Apple Books 朗读 | 仅支持 EPUB/PDF，无网页/Office，音色选择少 |
| 微信读书 AI 朗读 | 仅支持平台内书籍，不支持自定义文档 |
| Edge 浏览器朗读 | 仅网页，无法保存进度，无法离线 |
| Speechify | 付费（$139/年），部分格式受限 |

---

## 6. 用户故事

### 6.1 已实现

| ID | 角色 | 动作 | 价值 | 验收标准 |
|----|------|------|------|----------|
| US-001 | 用户 | 导入 PDF 文件 | 把 PDF 报告转成语音 | 1. 文件选择器支持 PDF<br>2. 提取文本并显示在播放器<br>3. 文本无乱码（含 OCR 回退） |
| US-002 | 用户 | 粘贴网页链接 | 听网页文章 | 1. 输入 URL 后自动获取<br>2. 只提取正文，不读导航/广告<br>3. 标题从 og:title 获取 |
| US-003 | 用户 | 通过 Safari 分享导入 | 浏览器中一键发送到 Knowledge | 1. 分享菜单显示 Knowledge<br>2. 打开 App 弹出确认导入对话框 |
| US-004 | 用户 | 调节语速 | 按自己习惯的速度听 | 1. 滑块调节 + 快捷档位按钮<br>2. 实时生效<br>3. 持久化保存 |
| US-005 | 用户 | 使用 TTS 引擎 | 系统 TTS 朗读文档 | 1. 系统 TTS 离线可用<br>2. 后续支持阿里云 CosyVoice 高品质语音 |
| US-006 | 用户 | 快进/快退 | 跳过已听内容或回听 | 1. 快进 30s / 快退 15s<br>2. 锁屏控制中心也可操作 |
| US-007 | 用户 | 继续上次阅读 | 不丢失阅读进度 | 1. 书库按最近打开排序<br>2. 重新打开从上次位置继续 |
| US-008 | 用户 | 导入 EPUB 电子书 | 把电子书转成有声书 | 1. 纯 Swift ZIP 解压<br>2. 正确解析 spine 顺序<br>3. 保留章节结构 |
| US-009 | 用户 | 切换主题模式 | 在白天/暗黑/跟随系统间切换 | 1. 设置页一键切换<br>2. 实时生效<br>3. 偏好持久化保存 |
| US-010 | 用户 | 边听边问 AI 伴读 | 听到不懂的内容随时提问 | 1. 播放器左上角💬按钮打开伴读（默认隐藏）<br>2. 进入时自动暂停朗读，退出时自动恢复<br>3. 支持多轮对话，携带当前朗读位置上下文 |

### 6.2 待实现

| ID | 角色 | 动作 | 价值 | 优先级 |
|----|------|------|------|--------|
| US-101 | 用户 | 一键 AI 总结文档 | 快速了解长文核心内容 | P0 |
| US-102 | 用户 | 录制声音并克隆 | 用自己的声音朗读 | P1 |
| US-103 | 用户 | 选择优质预设音色 | 找到最喜欢的朗读声音 | P1 |
| US-104 | 用户 | 将文档转为播客 | 获得双人对话式播客音频 | P2 |
| US-105 | 用户 | 导出播客音频 | 分享给朋友或发布到平台 | P2 |

---

## 7. 详细功能说明

### 7.1 文档导入模块

#### 7.1.1 文件导入
- **功能描述**：通过系统文件选择器导入本地文档
- **支持格式**：PDF、EPUB、DOCX、XLSX、PPTX、TXT、MD
- **主流程**：
  1. 用户点击书库「+」按钮
  2. 选择「导入文件」→ 系统 DocumentPicker 弹出
  3. 选择文件 → 复制到 App 沙盒
  4. 调用 TextExtractionService 提取文本
  5. 创建 Document 模型 → 存入 SwiftData
  6. 自动跳转播放器开始朗读
- **异常处理**：格式不支持 → 提示「暂不支持此格式」；提取失败 → 提示具体错误

#### 7.1.2 网页链接导入
- **功能描述**：输入 URL，自动获取网页内容并提取正文
- **主流程**：
  1. 用户点击「+」→ 选择「网页链接」
  2. 输入 URL → 点击确认
  3. HTTP 请求获取 HTML（User-Agent 伪装移动端）
  4. 编码自动检测（IANA charset → NSStringEncoding）
  5. 正文区域定位（article 标签 → 常见 class 选择器 → body 回退）
  6. 文本清洗（过滤导航/页脚/广告/版权声明/短噪音行）
  7. 标题提取（og:title → twitter:title → title 标签 → 域名）
- **异常处理**：网络超时 → 提示重试；无正文 → 提示「网页中无可提取的正文」

#### 7.1.3 Share Extension 导入
- **功能描述**：Safari 分享菜单一键发送到 Knowledge
- **主流程**：
  1. Safari 中点击分享 → 选择 Knowledge
  2. ShareExtension 接收 URL/文本 → 通过 App Group UserDefaults 传递
  3. 主 App 检测 `pendingShareURL` → 弹出确认对话框
  4. 确认后调用网页提取流程
- **异常处理**：App 未启动 → 冷启动后检测分享内容

### 7.2 文本提取引擎

#### 7.2.1 多格式解析策略

| 格式 | 解析方式 | 备注 |
|------|---------|------|
| **PDF** | PDFKit 文字提取 → Vision OCR 回退 | OCR 使用 accurate 级别，支持中英文 |
| **EPUB** | 纯 Swift ZIP 解压（含 Deflate）→ container.xml → content.opf → spine 解析 | 无第三方依赖 |
| **DOCX/XLSX/PPTX** | NSAttributedString RTF 解析 | 系统原生支持 |
| **Markdown** | 正则去除语法标记（YAML front matter/标题/加粗/斜体/代码块/链接/图片/引用/列表） | 保留纯文本 |
| **TXT** | 直接读取，编码自动检测 | UTF-8 / GBK 等 |
| **网页** | HTTP 请求 → NSAttributedString HTML 解析 → 正文定位 → 文本清洗 | 三层过滤 |

#### 7.2.2 网页正文定位算法

```
第一层：HTML 标签过滤
  移除 script/style/noscript/head/nav/footer/header/aside/iframe/form/button
  移除 HTML 注释

第二层：语义标签匹配（优先级从高到低）
  1. <article> 标签
  2. 常见正文 class：article-content / article_body / rich_media_content /
     post-content / entry-content / detail-content / article-text / news-content
  3. 常见正文 id：article-content / content / main-content / post-content
  4. <body> 回退（已剥离 nav/footer 等）

第三层：文本后处理清洗
  过滤关键词：首页/资讯/登录/注册/扫码/分享/下载APP/大家都在搜/
             相关阅读/风险提示/免责声明/广告/评论/点赞/Copyright
  过滤纯数字符号短行（≤5字符）
  过滤 URL 行
  合并连续空行（3+ → 2）
```

### 7.3 TTS 朗读引擎

#### 7.3.1 系统 TTS（SpeechService）

| 特性 | 说明 |
|------|------|
| 底层 | AVSpeechSynthesizer |
| 分块策略 | 500 字符/块，在句号/感叹号/问号/段落处截断 |
| 位置估算 | 3 字符/秒 |
| 快进/快退 | 停止当前 → 从目标位置重新开始 |
| 语言检测 | NSLinguisticTagger 自动检测主导语言 → 匹配最佳语音 |
| 支持语言 | 18 种（中文/英文/日文/韩文/法文/德文/西班牙文等） |

#### 7.3.2 引擎架构

```
SpeakerViewModel（Facade）
    ├── SpeechService（系统 TTS）
    │   └── AVSpeechSynthesizer
    └── 预留 CosyVoiceService（阿里云 TTS，待开发）
        └── HTTP REST → 阿里云 DashScope API
```

### 7.4 播放控制

| 操作 | 实现 |
|------|------|
| 播放/暂停 | 调用引擎 `speak()` / `pause()` |
| 快进 30s | 跳过当前块 → 从目标位置重新开始 |
| 快退 15s | 跳回前一块 → 从目标位置重新开始 |
| 语速调节 | 8 档预设（0.7x ~ 3x），实时生效 |
| 阅读高亮 | AttributedString 高亮 + 加粗 + 背景色，serif 字体 |
| 进度条 | 拖拽跳转 |
| 锁屏控制 | MPNowPlayingInfoCenter + MPRemoteCommandCenter |

### 7.5 主题模式

| 维度 | 内容 |
|------|------|
| **需求类型（KANO）** | 基本型 — 暗光环境下必备功能 |
| **目标** | 提供跟随系统、白天模式、暗黑模式三种外观选择，提升全天候使用体验 |

#### 实现内容

```
新增文件：
├── Models/ThemeMode.swift              # 主题模式枚举（system / light / dark）
└── Services/ThemeManager.swift         # 主题管理器（单例 + ObservableObject）

修改文件：
├── App/KnowledgeApp.swift              # 注入 ThemeManager，绑定 preferredColorScheme
├── Views/SettingsView.swift            # 新增「外观」Section，三个选项可切换
├── Views/ContentView.swift           # .tint(.blue) → .tint(.accentColor)
├── Views/DocumentRowView.swift       # 硬编码 .blue → .accentColor
├── Views/PlayerView.swift            # 高亮/渐变/Slider 颜色 → .accentColor
├── Views/PlayerControlsView.swift    # 按钮/语速档位颜色 → .accentColor
├── Views/DocumentListView.swift      # 空状态按钮颜色 → .accentColor
└── Resources/Assets.xcassets/AccentColor.colorset  # 新增 AccentColor 颜色资源
```

#### 交互流程

```
设置页 → 「外观」Section
    ├── 跟随系统（circle.lefthalf.filled 图标）
    ├── 白天模式（sun.max.fill 图标）
    └── 暗黑模式（moon.fill 图标）

点击任一选项 → 立即切换全局外观
    ↓
ThemeManager.mode 更新 → UserDefaults 持久化
    ↓
KnowledgeApp.preferredColorScheme 响应 → 全局 ColorScheme 切换
    ↓
所有视图自动适配（.primary / .secondary / .accentColor 动态响应）
```

#### 验收标准
1. 设置页显示三个选项，当前选中项显示 checkmark
2. 点击后 App 外观立即切换，无需重启
3. 选择「跟随系统」时，App 外观随 iOS 系统深色/浅色模式自动切换
4. 偏好持久化保存，下次打开 App 保持上次选择
5. 所有视图颜色使用 .accentColor，确保主题切换后颜色一致性
6. 高亮文本、进度条、按钮等交互元素在暗色模式下对比度充足

### 7.6 AI 伴读（预埋功能，默认隐藏）

| 维度 | 内容 |
|------|------|
| **需求类型（KANO）** | 兴奋型 — 边听边问的差异化体验 |
| **目标** | 用户在朗读过程中随时向 AI 提问，基于当前朗读位置的上下文进行多轮对话，获得类似朋友陪读的体验 |
| **当前状态** | 已实现并预埋，默认隐藏（`enableCompanion = false`），后续开启开关即可上线 |
| **技术方案** | 通义千问 qwen-plus（HTTP REST），携带朗读上下文，多轮对话历史（最多 10 轮） |

#### 实现内容

```
新增文件：
├── Services/CompanionService.swift      # AI 伴读网络层（单例）
│   ├── ask(question:context:)              # 向 AI 提问，携带朗读上下文
│   └── resetConversation()                # 重置对话历史（切换文档时调用）
├── Views/CompanionView.swift             # 伴读对话视图（Sheet 弹出）
└── Models/CompanionMessage.swift          # 对话消息模型（Identifiable）

修改文件：
├── ViewModels/SpeakerViewModel.swift      # 功能开关 + askCompanion/resetCompanion 方法
└── Views/PlayerView.swift               # 左上角💬按钮 + Sheet 弹出伴读视图
```

#### 交互流程

```
播放器页面 → 左上角💬气泡按钮（仅 enableCompanion = true 时显示）
    ↓
以 Sheet 弹出 CompanionView
    ↓
进入时：若正在朗读，自动暂停（companionPausedPlay 标记）
    ↓
欢迎界面（对话为空时）：
    ├── 图标 + 欢迎文案
    └── 快捷问题按钮：「这段讲了什么？」「解释一下关键概念」
    ↓
用户输入问题 / 点击快捷按钮
    ↓
调用 CompanionService.ask(question:context:)
    ├── 提取当前朗读位置前后 500 字作为上下文
    ├── 构建 system prompt（注入上下文 + 定义伴读角色）
    ├── 拼接多轮对话历史（最多 10 轮）
    └── 调用通义千问 qwen-plus API
    ↓
显示回复（气泡样式，用户蓝色右对齐 / AI 灰色左对齐）
    ↓
退出伴读：点击「继续听」或下滑关闭
    ↓
若进入时暂停了朗读，自动恢复播放
```

#### 验收标准
1. `enableCompanion = false` 时播放器不显示伴读按钮，功能完全不可见
2. `enableCompanion = true` 时左上角显示💬气泡按钮（accentColor）
3. 进入伴读时朗读自动暂停，退出时自动恢复
4. 快捷问题按钮可点击，点击后发送并显示回复
5. AI 回复简洁口语化，控制在 100 字以内
6. 多轮对话正常，上下文连贯（最近 10 轮）
7. 切换文档时对话历史自动重置
8. 网络失败时显示错误提示，不崩溃
9. 支持「清空对话」（右上角菜单 → 垃圾桶图标）
10. 消息列表自动滚动到最新消息

### 7.7 设置管理

| 设置项 | 范围 | 默认值 | 持久化 |
|--------|------|--------|--------|
| TTS 引擎 | 系统（后续 + 阿里云 CosyVoice） | 系统 | UserDefaults |
| 语速 | 0.1 ~ 2.0 | 0.5 | UserDefaults |
| 音高 | 0.5 ~ 2.0 | 1.0 | UserDefaults |
| 音量 | 0.0 ~ 1.0 | 1.0 | UserDefaults |
| 语言 | 18 种 | zh-CN | UserDefaults |
| 语音 | 按语言过滤 | 自动检测最佳 | UserDefaults |
| 主题模式 | 跟随系统 / 白天 / 暗黑 | 跟随系统 | UserDefaults |

---

## 8. 技术架构

### 8.1 架构概览

```
┌─────────────────────────────────────────────────┐
│                   Views 层                       │
│  ContentView → TabView（书库/播放/设置）           │
│  DocumentListView / PlayerView / SettingsView    │
│  CompanionView（Sheet 弹出）                     │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│                ViewModel 层                      │
│  SpeakerViewModel（Facade）                       │
│  ├── 播放控制 / 引擎切换 / 配置持久化               │
│  ├── AI 伴读（askCompanion / resetCompanion）      │
│  └── 状态同步（Timer 0.1s 轮询）                   │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│                Services 层                       │
│  TextExtractionService / SpeechService /         │
│  LanguageDetector / AudioSessionService /        │
│  NowPlayingService / ThemeManager /             │
│  CompanionService / AISummaryService             │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│                 Models 层                        │
│  Document（SwiftData） / VoiceConfig /            │
│  PlaybackState / ThemeMode / TTSEngine /         │
│  CompanionMessage / SummaryResult                │
└─────────────────────────────────────────────────┘
```

### 8.2 技术栈

| 层级 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 数据持久化 | SwiftData（Document 模型） |
| 配置存储 | UserDefaults（VoiceConfig / ThemeMode JSON 编解码） |
| 音频 | AVFoundation（AVSpeechSynthesizer / AVAudioPlayer） |
| 网络 | URLSession（HTTP 请求，通义千问 / CosyVoice API） |
| 文本提取 | PDFKit / Vision / CoreFoundation（ZIP Deflate） |
| 系统集成 | App Group / Share Extension / MPNowPlayingInfoCenter |
| 最低版本 | iOS 17.0 |

---

## 9. 数据模型

### 9.1 Document（SwiftData）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| title | String | 文档标题 |
| fileName | String | 原始文件名 |
| fileTypeRaw | String | 文档类型（持久化枚举值） |
| extractedText | String | 提取后的纯文本 |
| currentPosition | Int | 当前阅读位置（字符索引） |
| lastOpenedDate | Date | 最近打开时间 |
| createdAt | Date | 创建时间 |
| isFavorite | Bool | 是否收藏 |

### 9.2 VoiceConfig（UserDefaults JSON）

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| rate | Float | 0.5 | 语速（0.1~2.0） |
| pitchMultiplier | Float | 1.0 | 音高 |
| volume | Float | 1.0 | 音量 |
| language | String | "zh-CN" | 语言代码 |
| voiceIdentifier | String? | nil | 指定语音 ID |
| engine | TTSEngine | .system | TTS 引擎类型 |

### 9.3 ThemeMode（UserDefaults String）

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| rawValue | String | "跟随系统" | 三种选项：跟随系统 / 白天模式 / 暗黑模式 |
| colorScheme | ColorScheme? | nil | 映射到 SwiftUI ColorScheme（system→nil, light→.light, dark→.dark） |

### 9.4 CompanionMessage（内存模型，不持久化）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 自动生成主键 |
| content | String | 消息内容 |
| isUser | Bool | true=用户消息，false=AI 回复 |
| isLoading | Bool | 加载占位标记（默认 false） |

### 9.5 待扩展字段

| 模型 | 新增字段 | 用途 | 关联功能 |
|------|---------|------|----------|
| Document | summary | AI 摘要文本 | AI 总结 |
| Document | podcastAudioPath | 播客音频文件路径 | AI 播客 |
| VoiceConfig | clonedVoiceId | 克隆音色 ID | 语音克隆 |
| VoiceConfig | cosyVoicePreset | 预设音色选择 | 优质音色 |
| 新增 Podcast | — | 播客脚本/音频/状态 | AI 播客 |

---

## 10. 非功能需求

| 类别 | 要求 |
|------|------|
| **性能** | 文本提取：PDF < 5s（含 OCR）、EPUB < 3s、网页 < 3s（含网络请求） |
| **离线能力** | 系统 TTS 完全离线可用；主题模式完全离线；CosyVoice TTS 需联网（后续接入） |
| **兼容性** | iOS 17.0+，iPhone / iPad 适配 |
| **无障碍** | 支持 VoiceOver 导航；按钮有 accessibilityLabel |
| **隐私** | 不上传用户文档内容（除用户主动使用 AI 功能时）；API Key 不上传 GitHub |
| **可靠性** | 后续 CosyVoice 连接失败自动降级到系统 TTS，不中断用户体验 |
| **包体积** | 无第三方依赖（纯 Swift + 系统框架），保持轻量 |

---

## 11. 数据埋点（建议）

| 埋点位置 | 事件 ID | 触发条件 | 上报字段 |
|----------|---------|----------|----------|
| 文档导入 | doc_import | 成功导入文档 | format, file_size, import_method |
| 网页导入 | web_import | 成功导入网页 | url_domain, extraction_method |
| 播放开始 | play_start | 开始朗读 | engine_type, rate, language |
| 引擎切换 | engine_switch | 切换 TTS 引擎 | from_engine, to_engine |
| 引擎降级 | engine_fallback | CosyVoice 降级到系统 | error_reason |
| 主题切换 | theme_switch | 切换主题模式 | from_theme, to_theme |
| AI 伴读 | companion_ask | 用户向伴读提问 | doc_length, question_length, response_time |
| AI 总结 | ai_summary | 触发 AI 总结 | doc_length, response_time |
| 语音克隆 | voice_clone | 完成语音克隆 | audio_duration, clone_success |

---

## 12. 待开发功能详细规划

### 12.1 功能一：AI 文档总结

| 维度 | 内容 |
|------|------|
| **需求类型（KANO）** | 期望型 — 做得越好用户越满意 |
| **目标** | 用户导入文档后一键获取 AI 摘要，快速了解长文核心内容 |
| **技术方案** | 调用阿里云 DashScope 通义千问 API（HTTP POST），传入提取文本，返回摘要 |

#### 实现内容

```
新增文件：
├── Services/AISummaryService.swift      # AI 总结网络层
├── Views/SummaryCardView.swift           # 摘要展示卡片
└── Models/SummaryResult.swift            # 摘要结果模型

修改文件：
├── Views/PlayerView.swift                # 添加「AI 总结」按钮 + 加载态
├── ViewModels/SpeakerViewModel.swift     # 添加总结调用逻辑
└── Models/Document.swift                 # 添加 summary 字段
```

#### 交互流程

```
播放器页面 → 点击「AI 总结」按钮
    ↓
显示加载动画（「正在生成摘要...」）
    ↓
调用 AISummaryService.generateSummary(text:)
    ↓ POST /v1/chat/completions（通义千问）
    ↓
返回摘要 → 保存到 Document.summary
    ↓
弹出 SummaryCardView 展示
    ├── 摘要正文
    ├── 关键要点列表
    └── 「朗读摘要」按钮
```

#### 验收标准
1. 按钮在文本加载完成后可用，无文本时置灰
2. 加载中显示旋转动画 + 文字提示
3. 生成失败显示错误提示 + 重试按钮
4. 摘要内容保存到 Document 模型，下次打开可直接查看
5. 支持「朗读摘要」（调用当前 TTS 引擎朗读摘要文本）

---

### 12.2 功能二：语音能力增强（语音克隆 + 优质音色）

| 维度 | 内容 |
|------|------|
| **需求类型（KANO）** | 兴奋型 — 用户意想不到的亮点功能 |
| **目标** | 用户可以录制自己的声音并克隆为朗读音色；同时提供丰富的预设优质音色 |
| **推荐技术方案** | **阿里云 DashScope CosyVoice API**（HTTP REST，支持语音克隆 + 预设音色 TTS） |

#### 为什么选 CosyVoice

| 对比维度 | CosyVoice（DashScope） | Coze 语音 | 自建服务器 |
|----------|:---:|:---:|:---:|
| 语音克隆 | ✅ 3秒复刻 | ✅ | ✅ |
| 音质 | ⭐⭐⭐⭐⭐ 开源界顶尖 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 预设音色数量 | 丰富（几十种） | 有限 | 需自行配置 |
| 多音色合成 | ✅ 一句话指定不同音色 | ❌ | ✅ |
| 部署方式 | HTTP API 直接调 | HTTP API | GPU 服务器 |
| 免费额度 | 每月赠送 token | 有 | 无 |
| 与 AI 总结统一 | ✅ 同一平台 | ❌ 需要两套 | ❌ |

#### 实现内容

```
新增文件：
├── Services/CosyVoiceService.swift      # CosyVoice HTTP 网络层
│   ├── cloneVoice(audioData:)            # 上传音频 → 获取 voice_id
│   ├── synthesize(text:voiceId:)         # TTS 合成 → 返回音频
│   └── listVoices()                      # 获取音色列表（预设+克隆）
├── Views/VoiceCloneView.swift            # 录音 UI
│   ├── 引导文本展示（用户跟读）
│   ├── 录音/回放/重录按钮
│   └── 上传克隆 → 结果展示
├── Views/VoiceSelectView.swift           # 音色选择页
│   ├── 预设音色列表（试听）
│   ├── 我的克隆音色
│   └── 音色预览播放
└── Models/ClonedVoice.swift              # 克隆音色模型

修改文件：
├── Models/VoiceConfig.swift              # 新增 .cosyVoice 引擎、clonedVoiceId、presetVoiceId
├── Views/SettingsView.swift              # 「我的音色」入口 → VoiceCloneView
├── ViewModels/SpeakerViewModel.swift     # CosyVoice 引擎集成
└── Services/SpeechSynthesizerProtocol.swift  # 可能新增 CosyVoiceSynthesizer
```

#### 交互流程

```
【语音克隆】
设置页 → 「我的音色」→ 「录制我的声音」
    ↓
展示引导文本（约 30 字短文）
    ↓
用户朗读并录音（10-30 秒）
    ↓
回放确认 / 重新录制
    ↓
点击「开始克隆」→ 上传音频到 CosyVoice API
    ↓
返回 voice_id → 保存到 VoiceConfig
    ↓
显示成功提示：「你的声音已就绪！」

【音色选择】
设置页 → 音色选择 → 预设音色列表
    ├── 试听按钮（播放示例音频）
    ├── 分类筛选（男声/女声/中英文/播客风格等）
    └── 选中后实时生效
```

#### 验收标准
1. 录音引导文本清晰，用户可顺利完成录制
2. 录音时长不足 5 秒时提示「录音时间过短」
3. 克隆过程中显示进度（上传中 → 处理中 → 完成）
4. 克隆失败显示错误原因 + 重试
5. 预设音色列表加载流畅，试听响应 < 2s
6. 选择音色后播放器立即使用新音色
7. 克隆音色持久化保存，删除 App 后重新登录可恢复

---

### 12.3 功能三：AI 播客

| 维度 | 内容 |
|------|------|
| **需求类型（KANO）** | 兴奋型 — 产品差异化核心亮点 |
| **目标** | 将用户上传的文档或网页自动转为双人对话式播客音频，类似 Google NotebookLM 的音频概览功能 |
| **推荐技术方案** | 通义千问 LLM 生成对话脚本 + CosyVoice 多音色合成 + 音频拼接 |

#### 核心流程

```
用户文档/网页
    ↓
① AI 生成对话脚本（通义千问 LLM）
    Prompt: "将以下文章转为双人播客对话，角色A为主持人（引导+总结），
            角色B为嘉宾（深度分析+观点），语言自然口语化，时长约5-10分钟"
    输出:
        主持人A: 今天我们来聊聊韩国存储芯片扩产的事...
        嘉宾B: 没错，野村证券最新研报认为这是过度反应...
        主持人A: 那具体原因是什么呢？
        嘉宾B: 主要有两点...
    ↓
② 解析脚本 → 分配音色
    主持人 → 预设音色「沉稳男声」
    嘉宾   → 预设音色「知性女声」
    ↓
③ CosyVoice 逐段合成（指定不同 voice_id）
    段1: voice_id_A + 主持人文本 → audio_1.mp3
    段2: voice_id_B + 嘉宾文本 → audio_2.mp3
    段3: voice_id_A + 主持人文本 → audio_3.mp3
    ...
    ↓
④ 拼接音频 + 可选背景音乐/转场音效
    ↓
⑤ 输出完整播客音频文件 → 保存到 Document.podcastAudioPath
```

#### 实现内容

```
新增文件：
├── Services/PodcastService.swift         # 播客生成服务
│   ├── generateScript(text:)              # LLM 生成对话脚本
│   ├── parseScript(script:)               # 解析角色对话
│   ├── synthesizeSegments(segments:)      # 多音色逐段合成
│   └── mergeAudio(segments:)              # 拼接 + 背景音
├── Views/PodcastView.swift                # 播客播放器
│   ├── 生成进度（脚本撰写 → 音频合成 → 完成）
│   ├── 播客播放控制
│   ├── 当前发言人标识
│   └── 导出/分享按钮
├── Views/PodcastListView.swift            # 播客列表
└── Models/Podcast.swift                   # 播客数据模型
    ├── script: [DialogueSegment]           # 对话脚本
    ├── audioPath: String                   # 音频文件路径
    ├── status: PodcastStatus               # 生成状态
    └── createdAt: Date

修改文件：
├── Views/ContentView.swift                # TabView 新增「播客」Tab
├── Views/PlayerView.swift                 # 添加「生成播客」按钮
└── Models/Document.swift                  # 添加 podcastAudioPath
```

#### 交互流程

```
播放器页面 → 点击「生成播客」
    ↓
弹出确认对话框：「将本文档转为双人播客？预计耗时 1-3 分钟」
    ↓
确认 → 跳转 PodcastView 显示进度
    ├── 阶段1：正在生成对话脚本...（调用 LLM）
    ├── 阶段2：正在合成语音...（调用 CosyVoice，显示 3/15 段）
    └── 阶段3：正在拼接音频...
    ↓
完成 → 播客播放器界面
    ├── 封面（文档标题 + 自动生成封面）
    ├── 播放/暂停/进度条
    ├── 当前发言人高亮（主持人A / 嘉宾B）
    ├── 脚本字幕同步滚动
    └── 导出按钮（分享音频文件）
```

#### 验收标准
1. 生成按钮在文本 ≥ 500 字时才可用（内容太少不适合播客）
2. 生成过程显示分阶段进度，不阻塞 UI
3. 生成的对话脚本自然流畅，口语化，无明显 AI 痕迹
4. 两个角色音色有明显区分，听众能分辨谁在说话
5. 播客时长 5-15 分钟（根据原文长度自适应）
6. 播放时显示当前发言人标识 + 脚本字幕
7. 支持导出音频文件（分享到其他 App）
8. 生成失败支持重试，不丢失已生成的脚本
9. 后台生成支持（用户可离开页面）

---

## 13. 产品路线图

```
V1.0 ✅ 已完成
├── 多格式导入（PDF/EPUB/DOCX/XLSX/PPTX/TXT/MD/网页）
├── 系统 TTS 朗读引擎
├── 书库管理（SwiftData）
├── 播放控制（播放/暂停/快进/快退）
├── 阅读高亮
├── 锁屏控制
└── Share Extension

V1.1 ✅ 已完成
├── 语言自动检测
└── 引擎架构优化

V1.2 ✅ 已完成
├── 网页正文智能提取（三层过滤）
├── 移除 Edge TTS（不可用），统一后续 TTS 方案为阿里云 CosyVoice
└── 代码精简，移除冗余引擎切换逻辑

V1.3 ✅ 已完成
├── 主题模式（跟随系统 / 白天 / 暗黑）
├── 项目重命名为 Knowledge
├── 添加 Assets.xcassets（AccentColor + AppIcon）
└── 全局颜色适配（.blue → .accentColor）

V1.4 ✅ 已完成（当前版本）
├── AI 伴读（预埋功能，默认隐藏）
├── 边听边问的多轮对话（通义千问 qwen-plus）
├── 携带朗读位置上下文（前后 500 字）
└── 自动暂停/恢复朗读

V2.0 🔲 规划中
├── AI 文档总结（通义千问）
├── CosyVoice TTS 引擎集成（高品质语音）
├── 语音克隆（CosyVoice）
├── 预设优质音色选择
├── 引擎降级（CosyVoice → 系统 TTS）
└── 开启 AI 伴读功能开关

V3.0 🔲 规划中
├── AI 播客生成
├── 播客导出与分享
└── 更多播客风格模板
```

---

## 14. 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| **阿里云 API 不可用** | 低 | 中 | 降级到系统 TTS；系统 TTS 离线可用 |
| **阿里云 API 费用超预期** | 中 | 中 | 设置用量告警；优先使用免费额度；本地缓存摘要 |
| **AI 生成内容质量不可控** | 中 | 高 | 增加用户反馈机制；提供重新生成选项 |
| **语音克隆隐私风险** | 低 | 高 | 音频仅用于克隆，处理完即删除；隐私政策明示 |
| **播客生成耗时过长** | 高 | 中 | 后台任务生成；分阶段展示进度；支持取消 |
| **App Store 审核（AI 生成内容）** | 中 | 中 | 遵循 App Store 审核指南；标注 AI 生成内容 |
| **网页提取准确率不足** | 低 | 中 | 三层过滤已覆盖主流 CMS；用户可手动编辑文本 |

---

## 15. 附录

### 15.1 项目文件结构

```
Knowledge/
├── App/
│   ├── KnowledgeApp.swift           # @main 入口（注入 ThemeManager）
│   └── AppDelegate.swift             # 音频会话配置
├── Models/
│   ├── Document.swift                # 核心数据模型（SwiftData）
│   ├── VoiceConfig.swift             # 语音配置
│   ├── PlaybackState.swift           # 播放状态枚举
│   ├── ThemeMode.swift               # 主题模式枚举
│   ├── SummaryResult.swift           # AI 摘要结果模型
│   └── CompanionMessage.swift        # AI 伴读对话消息模型
├── Services/
│   ├── TextExtractionService.swift   # 文本提取引擎（748行）
│   ├── SpeechService.swift           # 系统 TTS 引擎
│   ├── SpeechSynthesizerProtocol.swift # TTS 引擎抽象协议
│   ├── CosyVoiceService.swift        # 阿里云 CosyVoice 网络层
│   ├── CosyVoiceSynthesizer.swift    # CosyVoice TTS 合成器
│   ├── AISummaryService.swift        # AI 总结网络层
│   ├── CompanionService.swift        # AI 伴读网络层（多轮对话）
│   ├── AudioSessionService.swift     # 音频会话管理
│   ├── LanguageDetector.swift        # 语言自动检测
│   ├── NowPlayingService.swift       # 锁屏控制中心
│   ├── ErrorHandler.swift            # 全局错误处理
│   ├── ShareExtensionHandler.swift   # Share Extension 处理
│   └── ThemeManager.swift            # 主题模式管理器
├── ViewModels/
│   └── SpeakerViewModel.swift        # 主 ViewModel（Facade）
├── Views/
│   ├── ContentView.swift             # 根视图（TabView）
│   ├── DocumentListView.swift        # 书库列表
│   ├── DocumentRowView.swift         # 文档行
│   ├── PlayerView.swift              # 播放器（含伴读/总结入口）
│   ├── PlayerControlsView.swift      # 播放控制
│   ├── CompanionView.swift           # AI 伴读对话视图
│   ├── SummaryCardView.swift         # AI 摘要卡片
│   ├── VoiceCloneView.swift          # 语音克隆录制页
│   ├── VoiceSelectView.swift         # 音色选择页
│   └── SettingsView.swift            # 设置（含主题模式）
├── UIKit/
│   └── DocumentPicker.swift           # 文件选择器桥接
├── ShareExtension/
│   └── ShareViewController.swift     # Safari 分享扩展
└── Resources/
    ├── Assets.xcassets/              # AppIcon + AccentColor
    └── Info.plist                    # 应用配置
```

### 15.2 关键设计决策

| 决策 | 理由 |
|------|------|
| 纯 Swift 无第三方依赖 | 降低维护成本，避免依赖地狱 |
| SwiftData 而非 Core Data | 现代化 API，SwiftUI 原生集成 |
| Facade 模式管理多引擎 | 对外统一接口，对内灵活切换（后续 CosyVoice 接入时无缝扩展） |
| EPUB 纯 Swift ZIP 解压 | 避免引入 ZipFoundation 等依赖 |
| Edge TTS 移除 | 微软接口不可用，后续统一使用阿里云 CosyVoice |
| 网页正文三层过滤 | 通用 HTML 语义分析，不针对特定网站 |
| UserDefaults 存配置 | 配置项轻量，无需数据库 |
| preferredColorScheme 驱动主题 | SwiftUI 原生方案，无需自定义颜色系统 |
| .accentColor 替代硬编码 .blue | 确保主题切换后所有交互元素颜色一致 |
| AI 伴读功能预埋 + 开关控制 | 代码已实现但默认隐藏，后续一键开启，避免发版时临时开发 |

### 15.3 术语表

| 术语 | 说明 |
|------|------|
| TTS | Text-to-Speech，文字转语音 |
| CosyVoice | 阿里开源的多语言语音合成模型，后续主力 TTS 引擎 |
| DashScope | 阿里云大模型 API 平台（通义千问 + CosyVoice） |
| 通义千问 | 阿里云大语言模型，AI 伴读/摘要的底层引擎（qwen-plus） |
| Facade | 外观模式，为子系统提供统一高层接口 |
| SwiftData | Apple 现代持久化框架（iOS 17+） |
| ThemeMode | 主题模式枚举（system / light / dark） |
| AccentColor | SwiftUI 强调色，自动适配暗色模式 |
| CompanionService | AI 伴读服务，基于通义千问的多轮对话，携带朗读上下文 |
