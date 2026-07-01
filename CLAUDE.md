# CLAUDE.md — echotalk_app（客户端 / Flutter）

> EchoTalk「影子跟读」项目的**移动客户端**（轻量多仓之一）。完整技术方案与 14 天内测计划见 Claude Project 知识库。接口以 **OpenAPI 契约**对齐，数据与鉴权来自 `echotalk_server`。

## 项目背景

EchoTalk 是面向全年龄段英语学习者的移动端 App，核心路径「跟读—发音—交流」。

- **内测范围**：影子跟读 + 账号体系 + 付费墙（**模拟购买**）。
- **平台**：Android + iOS（v1）；**内测仅 Android**；HarmonyOS 远期。
- **阶段**：单人开发，纯开发测试。开发者 Go 后端已熟，**Flutter 为新学栈**。
- **同项目其它仓**：`echotalk_server`（Go 后台）、`echotalk_manage`（Vue 管理端）。

## 本仓库角色

Flutter 单一代码库覆盖 Android/iOS（内测先 Android），承载影子跟读核心交互、账号、内容浏览/播放、付费墙与会员展示。

## 技术栈与关键库

- **Flutter / Dart**；状态管理 Riverpod 或 Bloc；网络 `dio`。
- **会话**：`flutter_secure_storage` 存 token + 自动刷新拦截器 + 路由守卫。
- **播放**：`better_player` / `video_player`（HLS）。
- **音频/变速**：`just_audio`（`setSpeed` **变速不变调**）。
- **录音**：`record`（**16K/16bit/单声道 WAV**）。
- **波形（可选）**：`audio_waveforms`。

## 关键约束

- **录音必须 16K/16bit/单声道 WAV**，匹配后端讯飞 ISE 评测。
- **不在客户端集成讯飞 SDK、不写原生桥接**：录音上传后端，由后端评测返回分数；客户端只负责录音、上传、展示评分与原声对照回放。
- **变速播放必须变速不变调**（`just_audio` setSpeed）。
- **付费/解锁以服务端为准**：客户端只做付费锁展示与付费墙（展示 SKU）。
- **内测支付是模拟购买**：调后端下单 + 模拟支付 → 刷新会员态 → 解锁。
- **影子跟读交互**：按 `start_ms/end_ms` 做句首/句尾定位与当前句循环；字幕随进度同步高亮。
- **仅 Android 内测**：用 network security config 允许对测试服务器的明文/IP 访问。
- **国内镜像**：配置 `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` 国内源，否则依赖拉取极慢。

## 部署与分发预期

- 内测出 **Android 包 → 上传蒲公英**分发，多机型冒烟。
- iOS 打包 / Apple IAP / HarmonyOS 均在**内测之后**。

## 风险与降级（单人 + Flutter 新学）

Flutter 是本项目唯一长杆。坚持最小闭环，吃紧时按序砍：写死单条内容（跳过列表）→ 去训练历史页 → 去波形/对照回放。优先保「跟读主流程 + 付费墙模拟闭环」质量。