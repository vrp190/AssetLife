# 格物 AssetLife

原生 iOS 资产管理 App（SwiftUI + SwiftData + Swift Charts，MVVM）。
按 `docs/IOS_ASSET_APP_SPEC.md` 规格实现：记录每一件物品的购入成本，自动计算
**日均成本**（购入价 ÷ 持有天数），帮助判断「这东西到底值不值」。

> 品牌说明：规格文档中的示例名称在本实现中重新品牌化为「格物」，
> 图标与视觉元素均为程序化原创设计（非截图复刻）。

## 运行环境

- Xcode 27.1（iOS 27.1 SDK），部署目标 **iOS 17.0+**，仅 iPhone（TARGETED_DEVICE_FAMILY = 1）
- Swift 5 语言模式，无第三方依赖

## 如何运行

```bash
# 方式一：Xcode
open AssetLife.xcodeproj
# Scheme 选 AssetLife，目标选任意 iPhone 模拟器，Cmd+R

# 方式二：命令行
xcodebuild build -project AssetLife.xcodeproj -scheme AssetLife \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/AssetLife-*/Build/Products/Debug-iphonesimulator/AssetLife.app
xcrun simctl launch booted com.gewu.AssetLife
```

## macOS 桌面版（另一个仓库）

macOS 原生 App（非 Catalyst）已拆分为**独立的 git 仓库**，与本仓库同级：

```
<工作目录>/AssetLife/       ← 本仓库（iOS）
<工作目录>/AssetLifeMac/    ← macOS 版仓库
```

```bash
open ../AssetLifeMac/AssetLifeMac.xcodeproj      # 用 Xcode 打开，⌘R 运行
# 或命令行：
cd ../AssetLifeMac
xcodebuild build -project AssetLifeMac.xcodeproj \
  -scheme AssetLifeMac -destination 'platform=macOS'
open ~/Library/Developer/Xcode/DerivedData/AssetLifeMac-*/Build/Products/Debug/AssetLifeMac.app
```

- 要求 **macOS 14.0+**（SwiftData 的最低版本），Bundle ID `com.gewu.AssetLife.mac`
- 界面为 Mac 原生范式：侧边栏 + Mail 式「列表 | 详情」双栏、⌘N 新增资产、
  ⇧⌘N 新增心愿、工具栏搜索与排序、表单 Sheet、系统文件导出/导入面板
- 代码复用方式：Mac 仓库内含一份 `Shared/` 业务层副本（Models / Services /
  ViewModels / 平台无关组件）。**改动共享逻辑时，请同时修改 `AssetLife/AssetLife/` 下
  的对应文件，避免两端行为分叉**
- 数据落地在 `~/Library/Application Support/default.store`（与 iOS 版数据相互独立）
- 已知环境限制：若在**已处于沙箱中的终端**（如某些自动化/CI 环境）执行
  `xcodebuild`，swift-plugin-server 会因嵌套沙箱无法启动，报
  `external macro implementation type ... produced malformed response`
  （iOS 与 macOS 目标都可能遇到）。此时加
  `OTHER_SWIFT_FLAGS='-disable-sandbox'` 即可正常构建；
  普通终端与 Xcode GUI 不需要（工程本身未写入该标志）。

调试启动参数与 iOS 版一致：`-SeedDemoData`。

## 如何运行测试

```bash
cd AssetLife
xcodebuild test -project AssetLife.xcodeproj -scheme AssetLife \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

当前共 **73 个单元测试用例**，全部通过（Debug 配置，iPhone 17 模拟器实测）：

| 套件 | 用例数 | 覆盖 |
| --- | --- | --- |
| `CostCalculatorTests` | 19 | 持有天数边界（当天=1 天/未来日期钳制）、按次/自定义成本、Decimal 精度、DST |
| `AssetStoreTests` | 8 | 内存存储 + SwiftData 内存容器增删改查、演示数据去重 |
| `AssetListViewModelTests` | 13 | 汇总统计（心愿排除）、筛选/搜索/排序、趋势聚合 |
| `AssetEditorViewModelTests` | 13 | 表单校验、保存/更新保留 ID、未保存修改检测 |
| `ExportServiceTests` | 10 | JSON 往返、各类损坏数据拒绝 |
| `CostTrendTests` | 10 | 趋势采样：≤62 天按天、跨月按月初、单点序列、按次/0 价返回空 |

## 工程结构

```
AssetLife/                         # 仓库根（iOS 版）
├── AssetLife/                     # App 目标（23 个 Swift 文件，约 3,750 行）
│   ├── App/AssetLifeApp.swift     # @main，ModelContainer（失败时退化内存存储）
│   ├── Models/                    # Asset（@Model）、枚举、分类
│   ├── Services/                  # CostCalculator、AssetStore、CostTrend、Export、Formatting
│   ├── ViewModels/                # AssetListViewModel、AssetEditorViewModel
│   ├── Views/                     # 总览/详情/编辑/心愿/趋势/设置 六个页面
│   ├── Components/                # 品牌色板、卡片、空状态、筛选栏等
│   └── Resources/Assets.xcassets  # App 图标与主题色
├── AssetLifeTests/                # 单元测试目标（6 个文件，约 940 行）
├── Tools/                         # make_icon.py / make_project.py（图标与工程生成脚本）
└── docs/                          # IOS_ASSET_APP_SPEC.md + 冒烟截图
```

macOS 版在同级目录的独立仓库 `../AssetLifeMac/`。

## 架构

- **MVVM**：View（SwiftUI）→ ViewModel（纯逻辑，`AssetListViewModel` 为 struct；
  表单 VM 为 `@MainActor ObservableObject`）→ Service（`AssetStoreProtocol`）。
- **存储抽象**：UI 只依赖 `AssetStoreProtocol`；线上为 `SwiftDataAssetStore`，
  测试/预览为 `InMemoryAssetStore`，行为一致。
- **金额**：全程 `Decimal`，展示用 zh_CN 货币格式；解析容忍 `¥` 与千分位逗号。
- **成本口径**（设置页内有同款说明）：
  - 日均成本 = 购入价 ÷ 持有天数；购买当天按 1 天，未来日期钳制为当天。
  - 按次模式 = 购入价 ÷ 使用次数；自定义模式直接填日均金额。
  - 「资产总额」指历史购入成本总和（含已卖出），**不含心愿**；
    已卖出资产不计入当前日均成本。
- **趋势**：只基于现有记录按月聚合，不伪造每日历史值。

## 数据保存在哪里

所有数据保存在 **App 沙盒内的 SwiftData 本地 SQLite 存储**
（`Library/Application Support/default.store`），不上传服务器。
卸载 App 或点「清空本地数据」即删除。设置页可导出 JSON 备份、从备份导入
（导入前做版本/字段/价格/枚举/重复 ID 校验，并需二次确认覆盖）。

## 安装到自己的 iPhone（免费 Apple ID，7 天有效）

工程已预置 `CODE_SIGNING_ALLOWED = YES` + `CODE_SIGN_STYLE = Automatic`，
用免费个人账号即可签名安装，无需付费开发者账号：

1. **登录 Apple ID**：Xcode → Settings → Accounts → 左下「+」→ 登录你的 Apple ID
   （免费账号即可，无需付费）。
2. **选择签名 Team**：点开工程蓝色图标 → TARGETS 选 `AssetLife` →
   Signing & Capabilities → 勾选 Automatically manage signing →
   Team 选你的 Apple ID（显示为「你的名字 (Personal Team)」）。
   若提示 `Failed to register bundle identifier`（说明 `com.gewu.AssetLife`
   被其他账号占用），把 Bundle Identifier 改成你自己的，
   如 `com.yourname.gewu`。
3. **安装**：数据线连接 iPhone 并解锁，弹出「信任此电脑」点信任；
   Xcode 顶部设备选你的 iPhone，按 Cmd+R。
4. **首次信任**：iPhone → 设置 → 通用 → VPN与设备管理 → 开发者App →
   点你的 Apple ID → 信任。
5. **7 天到期**：免费描述文件 7 天后 App 打不开。重新插线再按一次 Cmd+R
   即自动续签重装（会覆盖 App，数据清空——重装前用 App 内「导出 JSON」
   备份，重装后「导入」恢复；续签不换 Bundle ID 就不会重复弹信任）。
   省心方案是付费开发者账号（$99/年，有效期 1 年，还可用 TestFlight）。

免费账号限制：同时最多 3 个自签 App；部分能力不可用（推送、App Groups 等，
本 App 均未使用，不受影响）。

## 已知限制与工程决策

1. **单元测试为「无宿主（host-less）逻辑测试包」**：本环境的调试器无法附加到
   模拟器宿主 App（`xcodebuild test` 宿主模式启动失败），因此测试目标不设
   `TEST_HOST`，改为把 `Models/Services/ViewModels` 核心源码一并编入测试包，
   在裸 xctest 进程中直接运行。这也是为什么 `SwiftDataAssetStore` 额外提供
   `init(container:)`——`ModelContext` 不保留 `ModelContainer`，仅持有上下文
   会在容器释放后触发 SwiftData SIGTRAP 崩溃（测试中已实际复现并修复）。
2. **调试启动参数**（仅 `#if DEBUG` 编译，Release 不含）：
   - `-SeedDemoData`：启动时写入 10 条演示数据（同设置页「载入演示数据」路径）；
   - `-InitialTab=<0-3>`：直接打开指定 Tab（0 资产 / 1 心愿 / 2 趋势 / 3 设置）。
   ```bash
   xcrun simctl launch booted com.gewu.AssetLife -SeedDemoData
   ```
3. 图表与统计仅基于本地记录推导；无真实历史时不生成数据。
4. 首次启动为空状态，不自动写入任何演示数据。

## 冒烟验证记录（iPhone 17 模拟器，iOS 27.0，2026-10-24）

- 冷启动 → 空状态页正常渲染（品牌标题、汇总卡片、空状态引导、Tab 栏）。
- `-SeedDemoData` 启动 → 7 件资产 + 3 条心愿正确渲染；汇总数与手算一致
  （购入总成本 ¥21,473.00；心愿预算 ¥19,279.00 不计入总额）。
- 终止后不带参数重启 → 数据完整保留（持久化通过）。
- 心愿 / 趋势（Swift Charts 三图）/ 设置 四个 Tab 逐一渲染，无崩溃。
- **小屏适配**：另建 iPhone SE（3 代，4.7" / 375pt）真机验证——总览双列卡片
  右缘保留 16pt 背景边距（逐像素校验无裁切），趋势图与 Tab 栏无横向溢出。
- Debug 构建零代码警告；73/73 单元测试通过。

冒烟截图见 `docs/screenshots/`（空状态 / 演示数据 / 重启后 / 心愿 / 趋势 /
设置 / iPhone SE 小屏）。
