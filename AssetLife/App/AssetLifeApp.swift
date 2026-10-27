// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import SwiftUI
import SwiftData

@main
struct AssetLifeApp: App {

    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Asset.self)
        } catch {
            // 与 Xcode SwiftData 模板一致的兜底策略：磁盘存储不可用时退化为内存存储，
            // 保证应用可启动（数据不持久化），并在控制台输出原因。
            print("ModelContainer 初始化失败，退化为内存存储：\(error)")
            container = try! ModelContainer(
                for: Asset.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
#if DEBUG
        // 调试钩子：以 `-SeedDemoData` 参数启动时预写演示数据，
        // 用于在模拟器上快速验证列表渲染与“重启后数据仍在”。
        // 仅编译进 Debug；Release 构建不包含此逻辑。
        if ProcessInfo.processInfo.arguments.contains("-SeedDemoData") {
            MainActor.assumeIsolated {
                let store = SwiftDataAssetStore(container: container)
                _ = try? store.insertDemoData(referenceDate: Date())
            }
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(container)
        }
    }
}
