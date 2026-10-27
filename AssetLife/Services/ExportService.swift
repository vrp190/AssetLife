// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import Foundation

/// 导出/导入的数据结构。金额与日期均以字符串编码，保证往返不丢失精度。
struct AssetDTO: Codable, Equatable {
    var id: String
    var name: String
    var price: String
    var purchaseDate: String
    var category: String
    var status: String
    var kind: String
    var costMode: String
    var useCount: Int
    var iconName: String
    var notes: String
    var tags: [String]
    var createdAt: String
    var updatedAt: String
    var targetMode: String
    var targetValue: String?
    var targetDate: String?
    var isDemoData: Bool
}

/// 导出文件的外层结构，带格式版本号用于导入校验。
struct ExportPayload: Codable {
    static let currentFormatVersion = 1

    var app: String
    var formatVersion: Int
    var exportedAt: String
    var assetCount: Int
    var assets: [AssetDTO]
}

enum ExportError: Error, Equatable, LocalizedError {
    case invalidJSON
    case missingField(String)
    case unsupportedVersion(Int)
    case emptyPayload
    case invalidValue(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "不是有效的 JSON 文件"
        case .missingField(let field):
            return "缺少必需字段：\(field)"
        case .unsupportedVersion(let version):
            return "不支持的文件版本：\(version)"
        case .emptyPayload:
            return "文件中没有资产数据"
        case .invalidValue(let detail):
            return "字段值无效：\(detail)"
        }
    }
}

/// JSON 导出 / 导入服务。导入时执行格式与字段校验。
struct ExportService {

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Export

    static func makePayload(assets: [Asset], exportedAt: Date = Date()) throws -> Data {
        let dtos = assets.map { asset in
            AssetDTO(
                id: asset.id.uuidString,
                name: asset.name,
                price: NSDecimalNumber(decimal: asset.price).stringValue,
                purchaseDate: iso.string(from: asset.purchaseDate),
                category: asset.category,
                status: asset.status.rawValue,
                kind: asset.kind.rawValue,
                costMode: asset.costMode.rawValue,
                useCount: asset.useCount,
                iconName: asset.iconName,
                notes: asset.notes,
                tags: asset.tags,
                createdAt: iso.string(from: asset.createdAt),
                updatedAt: iso.string(from: asset.updatedAt),
                targetMode: asset.targetModeRaw,
                targetValue: asset.targetValue.map { NSDecimalNumber(decimal: $0).stringValue },
                targetDate: asset.targetDate.map { iso.string(from: $0) },
                isDemoData: asset.isDemoData
            )
        }
        let payload = ExportPayload(
            app: "AssetLife",
            formatVersion: ExportPayload.currentFormatVersion,
            exportedAt: iso.string(from: exportedAt),
            assetCount: dtos.count,
            assets: dtos
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    /// 导出文件的建议文件名。
    static func suggestedFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "AssetLife-\(formatter.string(from: now)).json"
    }

    // MARK: - Import

    /// 解析并校验导入数据。任何字段不合法都会抛出 `ExportError`。
    static func parsePayload(_ data: Data) throws -> [Asset] {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ExportPayload.self, from: data) else {
            throw ExportError.invalidJSON
        }
        guard payload.formatVersion == ExportPayload.currentFormatVersion else {
            throw ExportError.unsupportedVersion(payload.formatVersion)
        }
        if payload.assets.isEmpty {
            throw ExportError.emptyPayload
        }

        var result: [Asset] = []
        var seenIDs = Set<String>()
        for (index, dto) in payload.assets.enumerated() {
            guard !dto.name.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ExportError.missingField("assets[\(index)].name")
            }
            guard let price = Decimal(string: dto.price), price >= 0 else {
                throw ExportError.invalidValue("assets[\(index)].price = \(dto.price)")
            }
            guard let purchaseDate = iso.date(from: dto.purchaseDate) else {
                throw ExportError.invalidValue("assets[\(index)].purchaseDate")
            }
            guard let status = AssetStatus(rawValue: dto.status) else {
                throw ExportError.invalidValue("assets[\(index)].status = \(dto.status)")
            }
            guard let kind = AssetKind(rawValue: dto.kind) else {
                throw ExportError.invalidValue("assets[\(index)].kind = \(dto.kind)")
            }
            guard let costMode = CostMode(rawValue: dto.costMode) else {
                throw ExportError.invalidValue("assets[\(index)].costMode = \(dto.costMode)")
            }
            guard dto.useCount >= 0 else {
                throw ExportError.invalidValue("assets[\(index)].useCount")
            }
            guard let id = UUID(uuidString: dto.id) else {
                throw ExportError.missingField("assets[\(index)].id")
            }
            if seenIDs.contains(dto.id) {
                throw ExportError.invalidValue("assets[\(index)].id 重复")
            }
            seenIDs.insert(dto.id)

            let targetValue = dto.targetValue.map { Decimal(string: $0) ?? Decimal.zero } ?? nil
            let targetDate = dto.targetDate.flatMap { iso.date(from: $0) }
            let createdAt = iso.date(from: dto.createdAt) ?? purchaseDate
            let updatedAt = iso.date(from: dto.updatedAt) ?? createdAt

            result.append(Asset(
                id: id,
                name: dto.name.trimmingCharacters(in: .whitespaces),
                price: price,
                purchaseDate: purchaseDate,
                category: dto.category,
                status: status,
                kind: kind,
                costMode: costMode,
                useCount: dto.useCount,
                iconName: dto.iconName.isEmpty ? "cube.box.fill" : dto.iconName,
                notes: dto.notes,
                tags: dto.tags,
                createdAt: createdAt,
                updatedAt: updatedAt,
                targetMode: TargetDailyCostMode(rawValue: dto.targetMode) ?? .none,
                targetValue: targetValue,
                targetDate: targetDate,
                isDemoData: dto.isDemoData
            ))
        }
        return result
    }
}
