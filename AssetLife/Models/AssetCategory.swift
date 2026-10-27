// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation

/// 预置类别与默认图标。用户也可以输入自定义分类（以字符串存储）。
enum AssetCategory: String, CaseIterable, Identifiable {
    case electronics = "数码"
    case appliance = "家电"
    case furniture = "家具"
    case kitchen = "厨具"
    case clothing = "服饰"
    case sports = "运动"
    case instrument = "乐器"
    case book = "图书"
    case toy = "玩具"
    case vehicle = "交通"
    case health = "健康"
    case other = "其他"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .electronics: return "laptopcomputer"
        case .appliance: return "washer"
        case .furniture: return "bed.double.fill"
        case .kitchen: return "fork.knife"
        case .clothing: return "tshirt.fill"
        case .sports: return "figure.run"
        case .instrument: return "guitars.fill"
        case .book: return "books.vertical.fill"
        case .toy: return "puzzlepiece.fill"
        case .vehicle: return "bicycle"
        case .health: return "heart.fill"
        case .other: return "cube.box.fill"
        }
    }

    /// 根据分类名解析图标，未匹配到预置分类时返回默认图标。
    static func symbol(for name: String) -> String {
        AssetCategory(rawValue: name)?.systemImage ?? "cube.box.fill"
    }
}
