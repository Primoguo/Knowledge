# AI 伴读对话功能

<cite>
**本文引用的文件**
- [KnowledgeApp.swift](file://App/KnowledgeApp.swift)
- [AppDelegate.swift](file://App/AppDelegate.swift)
- [SpeakerViewModel.swift](file://ViewModels/SpeakerViewModel.swift)
- [CompanionService.swift](file://Services/CompanionService.swift)
- [CompanionMessage.swift](file://Models/CompanionMessage.swift)
- [CompanionView.swift](file://Views/CompanionView.swift)
- [PlayerView.swift](file://Views/PlayerView.swift)
- [SpeechService.swift](file://Services/SpeechService.swift)
- [CosyVoiceSynthesizer.swift](file://Services/CosyVoiceSynthesizer.swift)
- [AISummaryService.swift](file://Services/AISummaryService.swift)
- [Document.swift](file://Models/Document.swift)
- [SummaryResult.swift](file://Models/SummaryResult.swift)
- [ErrorHandler.swift](file://Services/ErrorHandler.swift)
- [VoiceConfig.swift](file://Models/VoiceConfig.swift)
- [SpeechSynthesizerProtocol.swift](file://Services/SpeechSynthesizerProtocol.swift)
</cite>

## 更新摘要
**已进行的变更**
- 增强了 CompanionService 的多轮对话历史和上下文管理功能
- 改进了 CompanionView 的用户界面，包括消息气泡、快捷问题和加载状态显示
- 优化了伴读与音频播放的协调机制，实现更流畅的暂停/恢复体验
- 新增 legacySystem TTS 引擎支持，提供更好的设备兼容性
- 完善了错误处理和降级机制

## 目录
1. [简介](#简介)
2. [项目结构](#项目结构)
3. [核心组件](#核心组件)
4. [架构总览](#架构总览)
5. [详细组件分析](#详细组件分析)
6. [依赖关系分析](#依赖关系分析)
7. [性能考量](#性能考量)
8. [故障排查指南](#故障排查指南)
9. [结论](#结论)

## 简介
本章节面向"AI 伴读对话"能力，说明其在应用中的定位、交互流程与关键实现要点。该功能在用户朗读文档时提供"边听边问"的交互式体验：进入对话界面自动暂停朗读，提问时将当前朗读位置上下文注入系统提示，调用云端大模型生成简短口语化回答；退出对话后恢复朗读。同时，该功能与播放控制、文本高亮、错误处理等模块协同工作。

**更新** 新增了 legacySystem TTS 引擎支持，提升了在不同 iOS 版本上的兼容性，并优化了伴读对话与音频播放的协调机制。

## 项目结构
围绕 AI 伴读对话的关键代码分布在以下层次：
- 应用入口与生命周期：初始化主题、数据容器、音频会话配置
- 视图层：播放器主界面与伴读对话界面
- 视图模型层：统一编排播放、摘要、伴读状态与事件
- 服务层：伴读对话服务（调用云端）、语音合成引擎（本地与云端）
- 数据模型：消息、文档、摘要结果、语音配置

```mermaid
graph TB
subgraph "应用"
A["KnowledgeApp<br/>应用入口"] --> B["ContentView<br/>主标签页"]
B --> C["PlayerView<br/>播放器界面"]
C --> D["CompanionView<br/>伴读对话界面"]
end
subgraph "视图模型"
E["SpeakerViewModel<br/>统一编排"]
end
subgraph "服务"
F["CompanionService<br/>伴读对话API"]
G["SpeechService<br/>系统TTS"]
H["CosyVoiceSynthesizer<br/>云端TTS"]
I["AISummaryService<br/>文档摘要"]
J["ErrorHandler<br/>全局错误处理"]
end
subgraph "模型"
K["CompanionMessage<br/>对话消息"]
L["Document<br/>文档实体"]
M["SummaryResult<br/>摘要结果"]
N["VoiceConfig<br/>语音配置"]
O["TTSEngine<br/>引擎类型"]
end
C --> E
D --> E
E --> F
E --> G
E --> H
E --> I
E --> J
D --> K
C --> L
I --> M
E --> N
N --> O
```

**图表来源**
- [KnowledgeApp.swift:1-29](file://App/KnowledgeApp.swift#L1-L29)
- [PlayerView.swift:1-187](file://Views/PlayerView.swift#L1-L187)
- [CompanionView.swift:1-200](file://Views/CompanionView.swift#L1-L200)
- [SpeakerViewModel.swift:1-384](file://ViewModels/SpeakerViewModel.swift#L1-L384)
- [CompanionService.swift:1-114](file://Services/CompanionService.swift#L1-L114)
- [SpeechService.swift:1-166](file://Services/SpeechService.swift#L1-L166)
- [CosyVoiceSynthesizer.swift:1-258](file://Services/CosyVoiceSynthesizer.swift#L1-L258)
- [AISummaryService.swift:1-180](file://Services/AISummaryService.swift#L1-L180)
- [CompanionMessage.swift:1-11](file://Models/CompanionMessage.swift#L1-L11)
- [Document.swift:1-115](file://Models/Document.swift#L1-L115)
- [SummaryResult.swift:1-33](file://Models/SummaryResult.swift#L1-L33)
- [ErrorHandler.swift:1-53](file://Services/ErrorHandler.swift#L1-L53)
- [VoiceConfig.swift:1-64](file://Models/VoiceConfig.swift#L1-L64)

## 核心组件
- 伴读对话服务：封装多轮对话、上下文注入、历史裁剪与错误映射
- 伴读对话视图：消息列表、快捷问题、输入栏、加载态与滚动定位
- 视图模型：编排伴读流程、提取上下文、管理消息队列与播放联动
- 语音引擎：系统 TTS、传统系统 TTS 与云端 CosyVoice 三引擎，支持切换与降级
- 错误处理：统一弹窗与日志输出

**更新** 新增了 legacySystem TTS 引擎支持，提供了更好的旧版本 iOS 兼容性。

**章节来源**
- [CompanionService.swift:1-114](file://Services/CompanionService.swift#L1-L114)
- [CompanionView.swift:1-200](file://Views/CompanionView.swift#L1-L200)
- [SpeakerViewModel.swift:1-384](file://ViewModels/SpeakerViewModel.swift#L1-L384)
- [SpeechService.swift:1-166](file://Services/SpeechService.swift#L1-L166)
- [CosyVoiceSynthesizer.swift:1-258](file://Services/CosyVoiceSynthesizer.swift#L1-L258)
- [ErrorHandler.swift:1-53](file://Services/ErrorHandler.swift#L1-L53)
- [VoiceConfig.swift:1-64](file://Models/VoiceConfig.swift#L1-L64)

## 架构总览
下图展示从 UI 到服务的数据与控制流，以及伴读对话与播放控制的协作关系。

```mermaid
sequenceDiagram
participant U as "用户"
participant PV as "PlayerView"
participant CV as "CompanionView"
participant VM as "SpeakerViewModel"
participant CS as "CompanionService"
participant API as "云端大模型API"
participant SS as "SpeechService/CosyVoice"
U->>PV : 点击"AI 伴读"
PV->>CV : 打开伴读对话框
CV->>VM : askCompanion(问题)
VM->>VM : 添加用户消息与loading占位
VM->>VM : extractCompanionContext()
VM->>CS : ask(question, context)
CS->>API : POST 请求(带system prompt+历史)
API-->>CS : 返回AI回复
CS-->>VM : 返回文本
VM->>VM : 移除loading并追加AI消息
Note over VM,SS : 进入伴读时暂停播放，退出时恢复
```

**图表来源**
- [PlayerView.swift:46-72](file://Views/PlayerView.swift#L46-L72)
- [CompanionView.swift:186-197](file://Views/CompanionView.swift#L186-L197)
- [SpeakerViewModel.swift:233-259](file://ViewModels/SpeakerViewModel.swift#L233-L259)
- [CompanionService.swift:24-112](file://Services/CompanionService.swift#L24-L112)

## 详细组件分析

### 伴读对话服务（CompanionService）
- 职责：构建 system prompt（角色定义 + 段落上下文），维护多轮消息历史，调用云端接口，解析响应并抛出领域错误
- 关键点：
  - 历史裁剪：保留最近若干轮，避免上下文过长
  - 错误映射：区分未配置/无效 API Key、网络或业务错误
  - 超时与鉴权：设置请求超时，处理 401/403
  - 多轮对话：支持连续问答，保持对话连贯性

**更新** 增强了多轮对话历史管理，现在可以保留最多 20 轮对话记录，提供更好的用户体验。

```mermaid
flowchart TD
Start(["开始"]) --> CheckKey["检查API Key是否存在"]
CheckKey --> |缺失| ErrMissing["抛出缺少API Key错误"]
CheckKey --> |存在| BuildPrompt["构建system prompt与messages"]
BuildPrompt --> CallAPI["发起HTTP请求"]
CallAPI --> RespOK{"HTTP 200?"}
RespOK --> |否| ErrAPI["抛出API错误"]
RespOK --> |是| Parse["解析JSON并提取content"]
Parse --> UpdateHistory["追加历史并裁剪"]
UpdateHistory --> Return(["返回AI回复"])
```

**图表来源**
- [CompanionService.swift:24-112](file://Services/CompanionService.swift#L24-L112)

**章节来源**
- [CompanionService.swift:1-114](file://Services/CompanionService.swift#L1-L114)
- [AISummaryService.swift:158-179](file://Services/AISummaryService.swift#L158-L179)

### 伴读对话视图（CompanionView）
- 职责：消息气泡渲染、欢迎语与快捷问题、输入框与发送逻辑、进入/退出时的播放联动
- 关键点：
  - 自动滚动到底部：新消息出现后滚动至最新
  - 加载态：显示"思考中..."占位
  - 工具栏：清空对话、继续听（返回播放器）
  - 快捷问题：提供常用问题按钮，提升用户体验
  - 智能焦点管理：自动聚焦输入框，提升操作效率

**更新** 改进了用户界面，新增了快捷问题按钮和更好的加载状态显示，同时优化了输入框的焦点管理。

```mermaid
classDiagram
class CompanionView {
+body
-messagesList
-welcomeMessage
-messageBubble(msg)
-inputBar
-sendMessage()
-sendQuestion(text)
}
class SpeakerViewModel {
+askCompanion(question) async
+resetCompanion()
+companionMessages
+isAskingCompanion
+companionPausedPlay
}
CompanionView --> SpeakerViewModel : "读取/更新状态"
```

**图表来源**
- [CompanionView.swift:1-200](file://Views/CompanionView.swift#L1-L200)
- [SpeakerViewModel.swift:233-259](file://ViewModels/SpeakerViewModel.swift#L233-L259)

**章节来源**
- [CompanionView.swift:1-200](file://Views/CompanionView.swift#L1-L200)

### 视图模型（SpeakerViewModel）
- 职责：对外暴露统一接口，协调播放、摘要、伴读；管理上下文提取、消息队列与引擎切换
- 伴读相关：
  - askCompanion：插入用户消息与 loading 占位，提取上下文，调用伴读服务，回写结果或错误
  - resetCompanion：清空消息与对话历史
  - extractCompanionContext：基于当前位置前后固定范围截取上下文
  - 播放联动：进入伴读暂停、退出恢复
  - 引擎切换：支持三种 TTS 引擎的动态切换

**更新** 增强了引擎切换逻辑，现在支持 legacySystem 引擎，并在引擎切换时更好地处理正在播放的状态。

```mermaid
sequenceDiagram
participant VM as "SpeakerViewModel"
participant CS as "CompanionService"
participant UI as "CompanionView"
UI->>VM : askCompanion(question)
VM->>VM : 追加用户消息与loading
VM->>VM : extractCompanionContext()
VM->>CS : ask(question, context)
CS-->>VM : response or error
VM->>VM : 替换loading为真实回复或错误提示
VM-->>UI : 触发UI刷新
```

**图表来源**
- [SpeakerViewModel.swift:233-259](file://ViewModels/SpeakerViewModel.swift#L233-L259)
- [CompanionService.swift:24-112](file://Services/CompanionService.swift#L24-L112)

**章节来源**
- [SpeakerViewModel.swift:1-384](file://ViewModels/SpeakerViewModel.swift#L1-L384)

### 语音引擎（SpeechService / CosyVoiceSynthesizer）
- SpeechService（系统 TTS）：按自然断点分块朗读，回调位置与范围变化，完成自动推进
- CosyVoiceSynthesizer（云端 TTS）：分段合成 MP3，顺序播放，定时估算位置，失败时回调错误以触发降级
- legacySystem 支持：通过 TTSEngine 枚举提供传统系统 TTS 选项，兼容旧版本 iOS

**更新** 新增了 legacySystem TTS 引擎支持，提供了更好的设备兼容性，特别是在 iOS 17 以下的设备上。

```mermaid
classDiagram
class SpeechSynthesizerProtocol {
<<interface>>
+state
+onPositionChange(pos)
+onRangeChange(range)
+onError(error)
+speak(text, from, config)
+pause()
+resume()
+stop()
+skipForward(by)
+skipBackward(by)
}
class SpeechService
class CosyVoiceSynthesizer
SpeechService ..|> SpeechSynthesizerProtocol
CosyVoiceSynthesizer ..|> SpeechSynthesizerProtocol
```

**图表来源**
- [SpeechService.swift:1-166](file://Services/SpeechService.swift#L1-L166)
- [CosyVoiceSynthesizer.swift:1-258](file://Services/CosyVoiceSynthesizer.swift#L1-L258)
- [SpeechSynthesizerProtocol.swift:1-20](file://Services/SpeechSynthesizerProtocol.swift#L1-L20)

**章节来源**
- [SpeechService.swift:1-166](file://Services/SpeechService.swift#L1-L166)
- [CosyVoiceSynthesizer.swift:1-258](file://Services/CosyVoiceSynthesizer.swift#L1-L258)
- [SpeechSynthesizerProtocol.swift:1-20](file://Services/SpeechSynthesizerProtocol.swift#L1-L20)

### 数据模型（CompanionMessage / Document / SummaryResult / VoiceConfig）
- CompanionMessage：消息内容、是否用户消息、加载态
- Document：文档元信息、提取文本、当前位置、进度、摘要缓存
- SummaryResult：摘要正文与要点列表，支持 JSON 序列化
- VoiceConfig：语音配置，包含引擎选择、音色设置等
- TTSEngine：语音引擎类型枚举，支持 system、knowledgeVoice、legacySystem

**更新** 新增了 TTSEngine 枚举，定义了三种不同的 TTS 引擎类型，提供了更好的引擎管理能力。

```mermaid
erDiagram
COMPANION_MESSAGE {
uuid id PK
string content
boolean isUser
boolean isLoading
}
DOCUMENT {
uuid id PK
string title
string fileName
string fileTypeRaw
string extractedText
int currentPosition
date lastOpenedDate
date createdAt
boolean isFavorite
string summary
string podcastAudioPath
}
SUMMARY_RESULT {
uuid id PK
string content
string keyPoints
date createdAt
}
VOICE_CONFIG {
float rate
float pitchMultiplier
float volume
string language
string voiceIdentifier
TTSEngine engine
string clonedVoiceId
string presetVoiceId
}
TTSENGINE {
string value
string displayName
string description
boolean isSupported
}
```

**图表来源**
- [CompanionMessage.swift:1-11](file://Models/CompanionMessage.swift#L1-L11)
- [Document.swift:1-115](file://Models/Document.swift#L1-L115)
- [SummaryResult.swift:1-33](file://Models/SummaryResult.swift#L1-L33)
- [VoiceConfig.swift:1-64](file://Models/VoiceConfig.swift#L1-L64)

**章节来源**
- [CompanionMessage.swift:1-11](file://Models/CompanionMessage.swift#L1-L11)
- [Document.swift:1-115](file://Models/Document.swift#L1-L115)
- [SummaryResult.swift:1-33](file://Models/SummaryResult.swift#L1-L33)
- [VoiceConfig.swift:1-64](file://Models/VoiceConfig.swift#L1-L64)

## 依赖关系分析
- 视图依赖视图模型：PlayerView 与 CompanionView 通过 @ObservedObject 订阅状态
- 视图模型聚合服务：SpeakerViewModel 组合伴读服务、语音引擎、摘要服务与错误处理器
- 伴读服务依赖网络与配置：从 UserDefaults 读取 API Key，向云端发起请求
- 语音引擎可插拔：通过协议抽象，运行时切换系统/云端引擎，并在出错时降级
- 引擎兼容性：支持多种 TTS 引擎，根据设备能力自动选择合适的引擎

**更新** 增强了引擎兼容性管理，现在可以根据设备能力和配置动态选择合适的 TTS 引擎。

```mermaid
graph LR
PlayerView --> SpeakerViewModel
CompanionView --> SpeakerViewModel
SpeakerViewModel --> CompanionService
SpeakerViewModel --> SpeechService
SpeakerViewModel --> CosyVoiceSynthesizer
SpeakerViewModel --> AISummaryService
SpeakerViewModel --> ErrorHandler
CompanionService --> |"HTTP"| CloudAPI
SpeakerViewModel --> VoiceConfig
VoiceConfig --> TTSEngine
```

**图表来源**
- [PlayerView.swift:1-187](file://Views/PlayerView.swift#L1-L187)
- [CompanionView.swift:1-200](file://Views/CompanionView.swift#L1-L200)
- [SpeakerViewModel.swift:1-384](file://ViewModels/SpeakerViewModel.swift#L1-L384)
- [CompanionService.swift:1-114](file://Services/CompanionService.swift#L1-L114)
- [VoiceConfig.swift:1-64](file://Models/VoiceConfig.swift#L1-L64)

**章节来源**
- [SpeakerViewModel.swift:1-384](file://ViewModels/SpeakerViewModel.swift#L1-L384)
- [CompanionService.swift:1-114](file://Services/CompanionService.swift#L1-L114)
- [VoiceConfig.swift:1-64](file://Models/VoiceConfig.swift#L1-L64)

## 性能考量
- 上下文长度控制：伴读上下文采用固定窗口（前后若干字符），避免过大请求体
- 历史裁剪：对话历史限制在最近若干轮，降低 token 消耗与延迟
- 语音分段：系统 TTS 按自然断点切块，云端 TTS 按段落合成，减少单次任务体积
- 异步与主线程：网络与合成在后台执行，UI 更新在主线程，避免卡顿
- 资源释放：停止播放时清理临时文件与定时器，防止内存泄漏
- 引擎选择：根据设备能力选择合适的 TTS 引擎，平衡音质与性能

**更新** 新增了引擎选择策略，考虑设备能力和用户需求，提供更优化的性能表现。

## 故障排查指南
- 常见问题
  - 未配置 API Key：伴读与摘要均会抛出"缺少 API Key"错误
  - API Key 无效：服务端返回鉴权错误，需检查密钥有效性
  - 网络异常：抛出网络错误，建议重试或检查网络环境
  - 云端 TTS 失败：自动降级到系统 TTS，可在设置中确认引擎状态
  - 引擎不支持：某些引擎在当前设备上不可用，会自动切换到支持的引擎
- 定位方法
  - 查看全局错误弹窗与控制台日志
  - 检查伴读消息中的错误提示
  - 验证 UserDefaults 中 API Key 是否正确写入
  - 检查当前选择的 TTS 引擎是否受支持

**更新** 新增了引擎兼容性相关的故障排查指导。

**章节来源**
- [AISummaryService.swift:158-179](file://Services/AISummaryService.swift#L158-L179)
- [ErrorHandler.swift:1-53](file://Services/ErrorHandler.swift#L1-L53)
- [SpeakerViewModel.swift:298-311](file://ViewModels/SpeakerViewModel.swift#L298-L311)
- [VoiceConfig.swift:26-33](file://Models/VoiceConfig.swift#L26-L33)

## 结论
AI 伴读对话功能以"边听边问"为核心体验，通过上下文注入与多轮历史保持对话连贯性；在工程上采用清晰的分层与协议抽象，使语音引擎可插拔、错误处理统一、UI 与状态解耦。本次更新增强了伴读服务的集成能力，改进了用户界面体验，并新增了 legacySystem TTS 引擎支持，提升了整体兼容性和稳定性。建议在后续迭代中持续优化上下文窗口策略、增加重试与退避机制，并对长文档场景进行更精细的分段与缓存策略。

**更新** 本次更新显著提升了功能的稳定性和用户体验，特别是通过新增的 legacySystem 引擎支持和改进的伴读对话界面，为用户提供了更加流畅和可靠的伴读体验。