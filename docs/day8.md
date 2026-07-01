# Day 8 — Flutter 脚手架 + 账号（App 可登录并保持会话）

## Context

EchoTalk 14 天内测冲刺进入第三阶段（客户端）。当前 `echotalk_app` 仓库尚无任何 Dart 代码，只有 `docs/`、`CLAUDE.md`、`README.md`，因此 Day 8 从零起 Flutter 工程。

Day 8 目标（来自冲刺计划 L155-165）：**App 能登录并保持会话**。这是后续 Day 9-12 全部页面的基座——网络层、鉴权态、路由守卫在此定型，一旦定下不宜返工，所以本日的重点是"把地基打对"，而非堆页面。

后端已就绪（`echotalk_server`，Day 2 账号模块完成），本仓通过 OpenAPI 契约对齐。关键契约事实（来自 `echotalk_server/api/openapi.yaml` 与 `docs/api-conventions.md`）：

- 业务基址 `/api/v1`，服务端口 `:8080`，健康检查在根 `/healthz`。
- 统一响应信封：`{ code, msg, data, request_id }`，`code=0` 成功；响应头带 `X-Request-ID`。
- `POST /user/login` → `TokenPair{access_token, refresh_token}`，**不含用户信息**；用户信息需另调 `GET /user/profile`。
- `POST /user/register` → 返回 `User`（非 token），验证码内测固定 `123456`；注册后仍需登录。
- `POST /user/refresh`（body `{refresh_token}`）→ 新 `TokenPair`。
- `POST /user/logout` → 撤销 refresh 会话（需带 access token）。
- access token TTL **2h**，refresh token TTL **720h（30 天）**（`configs/config.example.yaml`）。
- **401/code 10401** = 登录失效（传输级 HTTP 401）；**业务拒绝**（如密码错 `11003`）走 **HTTP 200 + 非 0 code**。刷新拦截器据此判定：仅 HTTP 401 触发刷新，200 内的业务码在页面层提示。

### 本日决策（已与用户确认）
- 状态管理：**Riverpod**（轻、样板少、编译期安全，适合单人 + Flutter 新手）。
- 路由：**go_router**（官方、`redirect` 天然做鉴权守卫）。
- 网络：**dio**；Token 存储：**flutter_secure_storage**（约束见 `CLAUDE.md`）。
- 后端目标：**先连本地** `echotalk_server:8080`；Android 模拟器用 `10.0.2.2`，baseUrl 用 `--dart-define` 可配。
- 范围：**登录页 + 最简注册页**（邮箱/密码/固定验证码 123456 → 注册 → 自动登录），方便自助造测试账号。
- JSON 解析：**手写 fromJson**，不引入 build_runner/freezed，减少 Flutter 新手心智负担。

## 任务分解（DoD 对齐冲刺计划）

### T1 — 工程初始化与依赖
- 在仓库根执行 `flutter create --org com.echotalk --project-name echotalk_app --platforms android,ios .`（在已有 `docs/`、`CLAUDE.md` 的非空目录中安全追加，不覆盖既有文件）。
- 配置国内镜像（`CLAUDE.md` 约束）：`export PUB_HOSTED_URL=https://pub.flutter-io.cn`、`FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn` 后再 `flutter pub get`。
- `pubspec.yaml` 加依赖：`flutter_riverpod`、`dio`、`go_router`、`flutter_secure_storage`（版本交给 `flutter pub add` 解析，锁进 `pubspec.lock`）。
- Android 明文放行：新增 `android/app/src/main/res/xml/network_security_config.xml`，允许对 `10.0.2.2` 与测试服 IP 的 cleartext；在 `AndroidManifest.xml` 的 `<application>` 引用 `android:networkSecurityConfig` 并加 `usesCleartextTraffic`（仅 debug 取向）。确认已有 INTERNET 权限（Flutter 默认注入 debug manifest）。

### T2 — 核心基建（core/）
- `core/config/env.dart`：`apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080/api/v1')`；健康检查基址单列。
- `core/network/api_response.dart`：`Envelope<T>` 解析 `{code,msg,data,request_id}`。
- `core/network/api_exception.dart`：把 HTTP 状态 + 业务 code 归一为带 `code/msg` 的 typed 异常，页面据此显示 `msg`（如 11003 密码错误）。
- `core/storage/token_storage.dart`：封装 flutter_secure_storage，读/写/清 `access_token`、`refresh_token`（提供 `read/save(pair)/clear`）。
- `core/network/dio_client.dart`：dio 实例（baseUrl、超时、`validateStatus` 放行 200 业务码），装配拦截器；对返回信封统一解封（code!=0 抛 `ApiException`）。
- `core/network/auth_interceptor.dart`：
  - `onRequest`：非鉴权豁免接口（login/register/refresh/send-code/healthz/system-config）附 `Authorization: Bearer <access>`。
  - `onError`：命中 **HTTP 401** 且非 refresh 接口且未重试过 → 加锁调 `/user/refresh`；成功则存新 pair 并**重放原请求**，失败则清 token 并置 `unauthenticated`（跳登录）。用锁/队列避免并发 401 触发多次刷新。

### T3 — 账号数据/领域层（features/auth/）
- `domain/token_pair.dart`、`domain/user.dart`（`User` + `UserProfile`，手写 fromJson，对齐 openapi schema）。
- `data/auth_api.dart`：`login`、`register`、`refresh`、`logout`、`sendCode`、`profile` 六个方法，直连上述端点。
- `data/auth_repository.dart`：编排 API + token 存储（登录成功即存 pair）。

### T4 — 鉴权状态与路由守卫
- `features/auth/application/auth_controller.dart`：Riverpod `Notifier<AuthState>`，状态 `unknown | authenticated(UserProfile) | unauthenticated`。
  - `bootstrap()`：读 token；无 → `unauthenticated`；有 → 拉 `/user/profile`，成功 `authenticated`，最终失败（含刷新失败）`unauthenticated`。
  - `login(email,pwd)` → 存 pair → 拉 profile → `authenticated`。
  - `register(email,pwd,nickname,code)` → 注册 → 复用 `login` 自动登录。
  - `logout()` → best-effort 调 logout → 清 token → `unauthenticated`。
- `core/router/app_router.dart`：go_router `redirect` 依据 `AuthState`——`unknown`→ splash；`unauthenticated`→ `/login`（放行 `/login`、`/register`）；`authenticated`→ 拦回受保护路由。`routes.dart` 存路由常量。

### T5 — 页面（features/…/presentation/）
- `auth/presentation/splash_page.dart`：启动触发 `bootstrap()`，转场时的 loading。
- `auth/presentation/login_page.dart`：邮箱/密码 + 登录按钮 + 去注册；错误用 `ApiException.msg` 提示；loading 态。
- `auth/presentation/register_page.dart`：邮箱/密码/昵称/验证码（预填 `123456`）+ 发送验证码（可选调 `send-code`）→ 注册成功自动登录。
- `home/presentation/home_page.dart`：登录后落地页（个人中心占位）——展示 `profile` 昵称/邮箱 + 登出按钮，验证会话有效。
- `app.dart` / `main.dart`：`ProviderScope` 包裹，`MaterialApp.router` 接 go_router。

## 关键文件
- 新建工程根：`lib/`（结构见上，feature-first + core 分层）、`pubspec.yaml`、`android/app/src/main/res/xml/network_security_config.xml`、`android/app/src/main/AndroidManifest.xml`。
- 契约来源（只读参考，勿改）：`echotalk_server/api/openapi.yaml`（账号段 L102-255、schema `TokenPair` L801、`User/UserProfile` L807-823）、`echotalk_server/docs/api-conventions.md`（信封与错误码）。

## 验证（端到端，对齐 Day 8 完成标准）
前置：本地起后端 `echotalk_server`（`docker compose` + `go run`，`:8080`），确保 `GET /healthz` 200。
1. **登录并保持**：`flutter run`（Android 模拟器，默认 baseUrl `10.0.2.2:8080`）→ 注册页造账号（验证码 123456）→ 自动登录进 home 见昵称。**杀进程重开** → 经 splash 直接进 home（token 持久化生效）。
2. **自动刷新**：验证 401→refresh→重放。因 access TTL 2h 不便干等，采用其一：临时把 `echotalk_server` `jwt.access_ttl` 调到如 `1m` 重启后端；或在 debug 下手动清掉 secure storage 里的 `access_token`（保留 refresh）后触发一次受保护请求（如刷新 profile）。预期：无感刷新、请求成功、home 不掉线。
3. **刷新失败跳登录**：把 refresh_token 改坏 / 调 logout 后再触发受保护请求 → 清 token → 自动跳 `/login`。
4. `flutter analyze` 无 error；`flutter run` 冷启动无红屏。

## 备注 / 风险
- iOS 平台文件一并生成但**内测不构建 iOS**（计划范围）；明文与联调只针对 Android。
- 若 Flutter 学习拖慢：本日可先砍注册页（回退到"仅登录页 + 后端预建账号"），但 T2/T4 的网络层与鉴权守卫是地基**不可砍**。
- 不在客户端做任何原生桥接 / 讯飞 SDK（`CLAUDE.md` 约束），Day 8 也不涉及。
