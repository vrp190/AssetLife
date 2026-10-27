// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 AssetLife contributors

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置页：导出/导入、演示数据、说明、清空数据。
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAssets: [Asset]

    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var showFileImporter = false
    @State private var pendingImport: [Asset]?
    @State private var showImportConfirm = false
    @State private var showClearStepOne = false
    @State private var showClearStepTwo = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var statusMessage: String?
    @State private var showStatus = false
    @State private var hasDemo = false

    private var store: AssetStoreProtocol {
        SwiftDataAssetStore(context: modelContext)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dataSection
                explanationSection
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .task {
            hasDemo = (try? store.hasDemoData()) ?? false
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL {
                ShareSheet(items: [shareURL])
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .confirmationDialog(
            "导入将覆盖全部现有数据？",
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button("导入并覆盖", role: .destructive) {
                performImport()
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            if let pendingImport {
                Text("文件包含 \(pendingImport.count) 条记录，导入后当前 \(allAssets.count) 条记录将被替换。")
            }
        }
        .alert("清空数据？", isPresented: $showClearStepOne) {
            Button("继续", role: .destructive) { showClearStepTwo = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除全部 \(allAssets.count) 条资产与心愿，此操作不可恢复。")
        }
        .alert("最后确认", isPresented: $showClearStepTwo) {
            Button("确认清空", role: .destructive) { performClear() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("清空后数据无法找回。建议先导出 JSON 备份。")
        }
        .alert("操作失败", isPresented: $showError) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("完成", isPresented: $showStatus) {
            Button("好") { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
    }

    // MARK: - 分区

    private var dataSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("数据")

                settingsRow(
                    title: "导出 JSON",
                    subtitle: "保存全部资产与心愿到文件",
                    systemImage: "square.and.arrow.up"
                ) {
                    exportJSON()
                }

                Divider().overlay(Brand.cardStroke)

                settingsRow(
                    title: "导入 JSON",
                    subtitle: "从备份文件恢复（含字段校验）",
                    systemImage: "square.and.arrow.down"
                ) {
                    showFileImporter = true
                }

                Divider().overlay(Brand.cardStroke)

                settingsRow(
                    title: hasDemo ? "清除演示数据" : "载入演示数据",
                    subtitle: hasDemo ? "删除全部标记为演示的条目" : "写入一份明确标注的示例数据",
                    systemImage: hasDemo ? "trash" : "sparkles"
                ) {
                    if hasDemo {
                        deleteDemoData()
                    } else {
                        loadDemoData()
                    }
                }

                Divider().overlay(Brand.cardStroke)

                settingsRow(
                    title: "清空本地数据",
                    subtitle: "删除所有资产与心愿（需二次确认）",
                    systemImage: "exclamationmark.triangle",
                    titleColor: Brand.destructive
                ) {
                    showClearStepOne = true
                }
            }
        }
    }

    private var explanationSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("说明")
                VStack(alignment: .leading, spacing: 10) {
                    Text("成本计算口径")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primaryText)
                    Text("日均成本 = 购入价格 ÷ 持有天数（购买当天按 1 天）。按次模式 = 购入价格 ÷ 使用次数。已卖出资产不计入当前日均成本，但其购入成本仍计入历史总额。“资产总额”指历史购入成本总和，不代表二手市场估值。")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("隐私说明")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primaryText)
                        .padding(.top, 6)
                    Text("所有数据仅存储在本机（SwiftData 本地数据库），不上传服务器，无第三方追踪。导出文件由你自行保管。")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("数据位置")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primaryText)
                        .padding(.top, 6)
                    Text("App 沙盒内的 SwiftData 本地存储；卸载 App 或点击“清空本地数据”将删除全部记录。")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var aboutSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                sectionTitle("关于")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("格物 AssetLife")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.primaryText)
                        Text("记录物品，理解每日成本。")
                            .font(.caption)
                            .foregroundStyle(Brand.secondaryText)
                    }
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Brand.primaryText)
            .padding(.vertical, 8)
    }

    private func settingsRow(
        title: String,
        subtitle: String,
        systemImage: String,
        titleColor: Color = Brand.primaryText,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                    .foregroundStyle(titleColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(titleColor)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Brand.secondaryText)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(subtitle)")
    }

    // MARK: - 行为

    private func exportJSON() {
        do {
            let data = try ExportService.makePayload(assets: allAssets)
            let url = try ShareFileHelper.temporaryURL(
                fileName: ExportService.suggestedFileName(),
                data: data
            )
            shareURL = url
            showShareSheet = true
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                errorMessage = "未选择文件"
                showError = true
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "无法读取所选文件"
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let assets = try ExportService.parsePayload(data)
                pendingImport = assets
                showImportConfirm = true
            } catch {
                errorMessage = "导入失败：\(error.localizedDescription)"
                showError = true
            }
        case .failure(let error):
            errorMessage = "无法选择文件：\(error.localizedDescription)"
            showError = true
        }
    }

    private func performImport() {
        guard let assetsToImport = pendingImport else { return }
        do {
            try store.deleteAll()
            for asset in assetsToImport {
                try store.addAsset(asset)
            }
            statusMessage = "已导入 \(assetsToImport.count) 条记录"
            showStatus = true
            pendingImport = nil
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func performClear() {
        do {
            try store.deleteAll()
            statusMessage = "已清空全部数据"
            showStatus = true
        } catch {
            errorMessage = "清空失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func loadDemoData() {
        do {
            let count = try store.insertDemoData(referenceDate: Date())
            hasDemo = count > 0
            statusMessage = count > 0 ? "已载入 \(count) 条演示数据（可在设置中一键清除）" : "已存在演示数据"
            showStatus = true
        } catch {
            errorMessage = "载入失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func deleteDemoData() {
        do {
            try store.deleteDemoData()
            hasDemo = false
            statusMessage = "演示数据已清除"
            showStatus = true
        } catch {
            errorMessage = "清除失败：\(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: Asset.self, inMemory: true)
}
