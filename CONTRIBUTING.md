# 贡献指南

感谢你愿意改进「格物 AssetLife」。本仓库是 **iOS 版**，macOS 版（`AssetLifeMac`）和
微信小程序版（`AssetLifeMiniProgram`）是另外两个独立仓库。

## 开始之前

- 较大改动（新功能、数据结构调整、成本口径变化）请先开 Issue 讨论，避免重复劳动。
- 本项目坚持 **零第三方依赖、纯本地数据、无网络请求**。引入网络库、统计 SDK、
  远程配置或任何运行时依赖的 PR 不会被接受。
- 三端「日均成本」口径必须一致：购入价 ÷ 持有天数，购买当天按 1 天，未来日期同样按 1 天；
  资产总额含已卖出、不含心愿；日均合计只含使用中 + 已退役。

## 环境

- Xcode 27.1，部署目标 iOS 17.0+，Swift 5 语言模式
- 仅 iPhone（`TARGETED_DEVICE_FAMILY = 1`）
- 无 CocoaPods / SPM 依赖

## 构建与测试

```bash
# 构建
xcodebuild build -project AssetLife.xcodeproj -scheme AssetLife \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# 单元测试（73 个用例）
xcodebuild test -project AssetLife.xcodeproj -scheme AssetLife \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

测试目标是「无宿主（host-less）」逻辑测试包：测试 target 会把
`Models/Services/ViewModels` 源码一并编入，在裸 xctest 进程中运行。
新增业务文件时记得在 Xcode 中勾选测试 target 的 Target Membership。

调试启动参数（仅 `#if DEBUG` 编译）：

- `-SeedDemoData`：启动时写入演示数据；
- `-InitialTab=<0-3>`：直接打开指定 Tab（0 资产 / 1 心愿 / 2 趋势 / 3 设置）。

## 代码约定

- 业务逻辑放在 `Models/Services/ViewModels`，不要 import SwiftUI；界面层只做展示与绑定。
- 金额一律用 `Decimal`，日期用 `Date`；不要用 `Double` 做金额运算。
- 任何行为变更都要有单元测试；修 bug 时先写一个能复现的失败用例。
- 注释解释「为什么」，不复述代码；面向用户的文案保持中文。
- 新建源文件时在首行加 SPDX 头：

  ```swift
  // SPDX-License-Identifier: AGPL-3.0-or-later
  // Copyright (C) 2026 AssetLife contributors
  ```

## 与 macOS 仓库同步

`AssetLifeMac/Shared/` 是 iOS 业务层的**实体副本**。修改 `Models/Services/ViewModels`
中的文件时，请同步修改 macOS 仓库中的对应文件，否则两端行为会分叉。

macOS 端可能包含少量额外接口（例如 `AssetStoreProtocol.replaceAll`、排序偏好存储键），
同步时不要把它们覆盖掉。

## 提交与 PR

- 提交信息用中文：第一行说明「改了什么 / 为什么」，需要时补正文与验证方式。
- 一个 PR 只做一件事；描述里附测试命令与结果（如 `73/73 通过`）和必要的截图。
- 不要提交构建产物、`xcuserdata`、`.DS_Store`、签名证书或任何密钥。
- 演示数据只能通过调试参数或测试写入，不能在正式启动路径自动写入。

## 许可证与贡献授权

本项目以 **AGPL-3.0-or-later** 发布，并提供商业授权（见 [LICENSING.md](LICENSING.md)）。
提交 PR 即表示你同意：

1. 你的贡献以 AGPL-3.0-or-later 授权；
2. 授予维护者一项非独占、永久、不可撤销、全球范围、免版税的许可，允许将你的贡献
   以其他许可证（包括商业许可证）再分发。

你保留自己贡献的版权，无需签署 CLA。若你的雇主对贡献主张版权，请先取得授权。

## 行为准则

请保持专业与尊重，围绕技术问题讨论；不接受人身攻击、歧视或骚扰。
