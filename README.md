# Bridge — 中文 Siri 助手

iPhone 中文语音桥接应用：保留 Siri 语言设置，通过 Bridge 理解中文并调用公开 iOS API。

首版包含 SwiftUI iPhone App、App Intents / App Shortcuts 入口、中文语音识别与朗读、OpenAI Responses 规划服务、动作校验与执行确认。

| 能力 | 实现 |
| --- | --- |
| 打开地图、音乐、微信 | 固定白名单，失败时明确反馈 |
| 创建提醒事项 | EventKit，支持指定时间 |
| 设置一次性闹钟 | AlarmKit，需 iOS 26；App 内可查看与取消 |
| 中文问答与澄清 | OpenAI 结构化输出 |
| 保留 Siri 语言 | Siri 英文短语入口，或操作按钮／轻点背面直接启动中文输入 |

**安装：[中文运行指南](docs/SETUP.zh-CN.md)** · **设计：[实现说明](docs/ARCHITECTURE.zh-CN.md)**

要求：iOS 17+（闹钟 iOS 26+）、Xcode 26+、Node.js 22+、自己的 HTTPS 服务及 OpenAI API 配置。

```sh
# 后端测试，无第三方依赖，无需 API Key
cd server
node --test

# 在 Mac 的仓库根目录测试 Swift 核心
swift test
```

在 Xcode 中打开 `ios/Bridge.xcodeproj`，选择自己的签名 Team 后运行到 iPhone。API Key 只放服务端，手机设置里填写的是服务地址与 Bridge 令牌。参见安装指南配置后端与入口。

普通侧边按钮仍由系统控制，第三方 App 不能读取 Siri 内部语音或注入 Siri 命令。Bridge 闹钟由本 App 管理，不修改系统时钟 App 的已有闹钟。执行结果使用本地中文模板，以真实系统 API 结果为准。

GitHub Actions 运行后端测试、Swift 核心测试与完整 iOS 模拟器编译。模拟器产物不是可直接安装的 iPhone IPA。真实 API 和真机录音、权限、响铃需按运行指南验收。
