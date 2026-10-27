// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import SwiftUI

/// 底部 Tab：资产 / 心愿 / 趋势 / 设置。
struct MainTabView: View {
    @State private var selectedTab = 0

    init() {
#if DEBUG
        // 调试钩子：以 `-InitialTab=<0-3>` 参数启动可直接打开指定 Tab
        // （0 资产 / 1 心愿 / 2 趋势 / 3 设置），便于逐一冒烟验证页面渲染。
        if let arg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-InitialTab=") }),
           let index = Int(arg.dropFirst("-InitialTab=".count)) {
            _selectedTab = State(initialValue: index)
        }
#endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                AssetOverviewView()
            }
            .tabItem {
                Label("资产", systemImage: "square.grid.2x2.fill")
            }
            .tag(0)

            NavigationStack {
                WishlistView()
            }
            .tabItem {
                Label("心愿", systemImage: "star.fill")
            }
            .tag(1)

            NavigationStack {
                TrendsView()
            }
            .tabItem {
                Label("趋势", systemImage: "chart.line.uptrend.xyaxis")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape.fill")
            }
            .tag(3)
        }
        .tint(Brand.accentDeep)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: Asset.self, inMemory: true)
}
