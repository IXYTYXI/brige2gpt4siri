# 安装与运行

## 你需要准备

- Mac、Xcode 26 或更新版本；iPhone iOS 17+。设置闹钟需要 iOS 26+。
- 可用的 OpenAI API Key 和支持 Responses Structured Outputs 的模型 ID。
- 自己控制的 HTTPS 服务地址；本项目不自动创建或收费部署云资源。
- Xcode 登录自己的 Apple 开发者账号，用于把 App 签名安装到自己的手机。

## 1. 启动服务

安装 Node.js 22+，克隆仓库后进入 `server`。无需安装 npm 依赖。

```sh
cp .env.example .env
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

把生成的随机字符串写入 `.env` 的 `BRIDGE_TOKEN`。填写 `OPENAI_API_KEY` 和 `OPENAI_MODEL`，不要把这些值发到公开仓库。

```dotenv
OPENAI_API_KEY=你的API密钥
OPENAI_MODEL=你有权限使用且支持结构化输出的模型ID
BRIDGE_TOKEN=上一步生成的随机字符串
HOST=127.0.0.1
PORT=8787
```

```sh
npm test
npm start
```

`GET /health` 应返回 `{"status":"ok"}`。健康检查不调用模型；实际理解请求才调用 API。

用自己已有的反向代理把 HTTPS 转发到 `127.0.0.1:8787`。例如在已安装的 Caddy 中配置：

```caddyfile
bridge.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

域名必须归你管理且指向这台服务器。Windows 上运行服务时同样可用 Node.js；iPhone 不能用 `localhost` 访问电脑。必须填写手机能访问且证书有效的 HTTPS 地址，不关闭 iOS 网络安全检查。服务默认只监听本机，适合放在反向代理后面。

这是单用户 MVP。令牌授予调用你的模型服务的权限，不能分享给不可信的人；可在服务端改令牌并重启进行撤销。30 次/分钟与 3 个并发是基础限流，不能替代 API 项目的消费限额。公网部署还应在反向代理限制连接数和请求大小。没有用户注册、多租户或持久会话功能。

## 2. 安装 iPhone App

1. 在 Mac 克隆仓库并切到实现分支（PR 合并后使用 `main`）。
2. 打开 `ios/Bridge.xcodeproj`，选择 `Bridge` scheme。
3. 在 Signing & Capabilities 选择自己的 Team；若 Bundle ID 冲突，修改 `com.ixytyxi.bridge`。
4. 连接 iPhone 并选择它为运行目标，按 Run。按照系统提示启用开发者模式、信任开发者。
5. App 内打开设置，填写 HTTPS 服务地址和 `BRIDGE_TOKEN`。这里不要填写 OpenAI API Key。
6. 阅读首次使用提示，然后输入「明天下午六点提醒我买牛奶」。点「理解请求」，核对标题和手机本地时间，再确认执行。

工程已生成并提交，不需要 XcodeGen。新增 Swift 文件后，在仓库根目录运行 `python3 scripts/generate-project.py` 更新工程。

CI 的 `Bridge-simulator` 产物只用于 Mac 上的 iOS 模拟器，**不能直接安装到 iPhone**。真机需要自己的签名。仓库不包含证书、私钥、API Key 或签名 IPA。

## 3. 不更改 Siri 语言的入口

普通侧边按钮仍由系统控制，Bridge 不能替换它，也不能读取 Siri 内部录音。

- **英语 Siri**：说 “Talk to Bridge” 或 “Start Bridge”。打开 Bridge 后由 App 使用 `zh-CN` 采集语音。
- **完全不说英语**：在快捷指令中加入 Bridge 的「开始中文对话」，将该快捷指令绑定到支持的 iPhone 操作按钮，或系统设置 → 辅助功能 → 触控 → 轻点背面。
- **现有快捷指令接入**：先用快捷指令「听写文本」并指定中文，再将结果传入 Bridge 的「输入中文请求」。App 打开后点击「理解请求」。

第一次先打开 App 完成配置与说明；麦克风和语音权限按需请求。锁屏时系统可能要求解锁。语音输入后点击「停止录音」，可以修改识别结果再发送。语音最多录制 55 秒。

## 4. 功能范围

| 功能 | 实现 | 约束 |
| --- | --- | --- |
| 中文文字/语音 | Speech + SwiftUI | 优先本地识别；设备不支持时 Apple 可能联网处理 |
| 中文回答/追问 | OpenAI Responses | 当前请求无历史会话；追问后请重新输入完整需求 |
| 打开 App | 固定 URL scheme 白名单 | 地图、音乐、微信；未安装会报错 |
| 提醒事项 | EventKit | 写入默认提醒列表；可选具体日期时间 |
| 闹钟 | AlarmKit | iOS 26+、一次性具体日期时间、由 Bridge 管理 |
| 查看/取消闹钟 | 设置 → 我的闹钟 | 仅管理 Bridge 创建的闹钟 |
| 反馈 | 本地中文结果 + AVSpeechSynthesizer | 执行结果以系统 API 返回为准 |

不支持重复闹钟、修改系统时钟已有闹钟、短信、电话、付款、任意 App 控制、多个动作串联。遇到这些请求会说明不支持或要求澄清，不转换成近似操作。旧 iOS 不用通知假装闹钟。

## 5. 真机验收清单

- [ ] Siri 保持原有语言，入口可打开 Bridge；操作按钮或轻点背面可启动中文输入。
- [ ] 麦克风/语音权限分别允许与拒绝时，界面反馈正确；文字输入始终可用。
- [ ] 录音停止、进入后台或 55 秒超时后麦克风停止。
- [ ] 创建提醒前能核对标题和完整日期时间，取消后系统列表无新增。
- [ ] 拒绝提醒权限不会显示成功；允许后默认列表只有一条新增提醒。
- [ ] iOS 26 同意闹钟权限，设两分钟后的闹钟，锁屏后响铃，停止和取消有效。
- [ ] 未安装微信时显示明确失败；地图/音乐可打开。
- [ ] 服务离线、令牌错误、模型拒答时不会执行动作。
- [ ] 连续点确认只执行一次；等待五分钟后旧确认失效。
- [ ] 「明天早上八点」按照手机时区显示，夏令时前后要人工核对。

## 官方接口依据

- [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- [Apple AlarmKit](https://developer.apple.com/documentation/alarmkit)
- [Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/alarmkit/scheduling-an-alarm-with-alarmkit)
- [App Intents](https://developer.apple.com/documentation/appintents)
- [EventKit](https://developer.apple.com/documentation/eventkit)
- [Speech](https://developer.apple.com/documentation/speech)
