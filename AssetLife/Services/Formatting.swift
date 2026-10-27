// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation

/// 统一的金额与日期格式化。界面不直接使用裸数字。
enum MoneyFormatter {

    /// 人民币格式，例如 ¥3,221.98（固定两位小数，千分位分组）。
    static func string(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return currencyFormatter.string(from: value as NSDecimalNumber) ?? "—"
    }

    /// 两位小数字符串（不带货币符号），用于图表标签等紧凑场景。
    static func plain(_ value: Decimal?) -> String {
        guard let value else { return "—" }
        return decimalFormatter.string(from: value as NSDecimalNumber) ?? "—"
    }

    /// 金额输入解析：容忍空白、千分位逗号、全角字符；非法输入返回 nil。
    static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .replacingOccurrences(of: "¥", with: "")
        return Decimal(string: normalized)
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

/// 日期格式化工具。
enum DateFormatterBox {
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    static let monthLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    static func dateString(_ date: Date) -> String {
        fullDate.string(from: date)
    }
}
