import SwiftUI
import SwiftData
import Charts

/// 资产详情页：日均成本主指标、基本信息、成本趋势、状态与删除操作。
struct AssetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let asset: Asset

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let trends = TrendsViewModel()

    private var days: Int { asset.holdingDays() }
    private var dailyCost: Decimal? { asset.effectiveDailyCost() }

    /// 由购买日期至今推导的月度日均成本序列（不伪造每日真实历史）。
    private var trendPoints: [(label: String, value: Decimal)] {
        let monthsSincePurchase = max(1, Calendar.current.dateComponents([.month], from: asset.purchaseDate, to: Date()).month ?? 0)
        let points = trends.monthlyPoints([asset], months: min(12, monthsSincePurchase + 1))
        return points.map { (DateFormatterBox.monthLabel.string(from: $0.monthStart), $0.dailyCostAsOf) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                heroCard
                statsRow
                if trendPoints.count >= 2 {
                    trendCard
                }
                infoCard
                if let target = asset.resolvedTargetDailyCost() {
                    targetCard(target: target)
                }
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Text("编辑")
                        .foregroundStyle(Brand.accentDeep)
                }
                .accessibilityLabel("编辑资产")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        setStatus(.inUse)
                    } label: {
                        Label("标记为使用中", systemImage: "circle.fill")
                    }
                    Button {
                        setStatus(.retired)
                    } label: {
                        Label("标记为已退役", systemImage: "moon.fill")
                    }
                    Button {
                        setStatus(.sold)
                    } label: {
                        Label("标记为已卖出", systemImage: "tag.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("更改状态")
            }
        }
        .sheet(isPresented: $isEditing) {
            AssetEditorView(asset: asset, defaultKind: asset.kind, store: SwiftDataAssetStore(context: modelContext))
                .environment(\.modelContext, modelContext)
        }
        .confirmationDialog(
            "删除“\(asset.name)”？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
                Button("删除", role: .destructive) {
                    do {
                        let store = SwiftDataAssetStore(context: modelContext)
                        try store.delete(asset)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，该资产的成本记录也会一并移除。")
        }
        .alert("删除失败", isPresented: $showError) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 子视图

    private var header: some View {
        HStack(spacing: 14) {
            IconBadge(systemImage: asset.iconName, size: 56, tint: Brand.statusColor(asset.status))
            VStack(alignment: .leading, spacing: 6) {
                Text(asset.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Brand.primaryText)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    StatusPill(status: asset.status)
                    Text(asset.category)
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                }
            }
            Spacer()
        }
    }

    private var heroCard: some View {
        CardContainer {
            VStack(spacing: 6) {
                Text(costModeTitle)
                    .font(.caption)
                    .foregroundStyle(Brand.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(MoneyFormatter.string(dailyCost))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.accentDeep)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(asset.costMode == .perUse ? "/次" : "/天")
                        .font(.callout)
                        .foregroundStyle(Brand.secondaryText)
                }
                Text(costModeCaption)
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    private var costModeTitle: String {
        switch asset.costMode {
        case .perDay: return "日均成本"
        case .perUse: return "单次成本"
        case .custom: return "自定义每日成本"
        }
    }

    private var costModeCaption: String {
        switch asset.costMode {
        case .perDay:
            return "购入价 ÷ 持有天数（购买当天按 1 天计）"
        case .perUse:
            return "购入价 ÷ 使用次数（已使用 \(asset.useCount) 次）"
        case .custom:
            return "使用你设定的固定金额"
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCell(title: "购入价格", value: MoneyFormatter.string(asset.price))
            statCell(title: "持有天数", value: "\(days) 天")
            statCell(title: "购买日期", value: DateFormatterBox.dateString(asset.purchaseDate))
        }
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Brand.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Brand.cardStroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private var trendCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("日均成本趋势")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                Text("按各月最后一天可推导数据绘制，非每日真实记录。")
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)
                Chart(trendPoints, id: \.label) { point in
                    LineMark(
                        x: .value("月份", point.label),
                        y: .value("日均成本", NSDecimalNumber(decimal: point.value).doubleValue)
                    )
                    .foregroundStyle(Brand.accentDeep)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    AreaMark(
                        x: .value("月份", point.label),
                        y: .value("日均成本", NSDecimalNumber(decimal: point.value).doubleValue)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Brand.accent.opacity(0.35), Brand.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 160)
            }
        }
    }

    private var infoCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                infoRow(title: "价格", value: MoneyFormatter.string(asset.price))
                Divider().overlay(Brand.cardStroke)
                infoRow(title: "类别", value: asset.category)
                Divider().overlay(Brand.cardStroke)
                infoRow(title: "购买日期", value: DateFormatterBox.dateString(asset.purchaseDate))
                Divider().overlay(Brand.cardStroke)
                infoRow(title: "状态", value: asset.status.title)
                Divider().overlay(Brand.cardStroke)
                infoRow(title: "成本模式", value: asset.costMode.title)
                if asset.costMode == .perUse {
                    Divider().overlay(Brand.cardStroke)
                    infoRow(title: "使用次数", value: "\(asset.useCount) 次")
                }
                if !asset.tags.isEmpty {
                    Divider().overlay(Brand.cardStroke)
                    HStack(alignment: .top) {
                        Text("标签")
                            .foregroundStyle(Brand.secondaryText)
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(asset.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Brand.accent.opacity(0.18))
                                    .foregroundStyle(Brand.primaryText)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .font(.subheadline)
                }
                if !asset.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider().overlay(Brand.cardStroke)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("备注")
                            .font(.subheadline)
                            .foregroundStyle(Brand.secondaryText)
                        Text(asset.notes)
                            .font(.subheadline)
                            .foregroundStyle(Brand.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                }
            }
            .font(.subheadline)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Brand.secondaryText)
            Spacer()
            Text(value)
                .foregroundStyle(Brand.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }

    private func targetCard(target: Decimal) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("目标日均成本")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                HStack {
                    Text("目标 " + MoneyFormatter.string(target) + "/天")
                        .font(.subheadline)
                        .foregroundStyle(Brand.secondaryText)
                    Spacer()
                    if let current = dailyCost, target > 0 {
                        let ratio = min(1.0, max(0.0, NSDecimalNumber(decimal: target / current).doubleValue))
                        Text("已达成 \(Int(ratio * 100))%")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.accentDeep)
                    }
                }
                if let current = dailyCost, target > 0 {
                    ProgressView(value: min(1.0, max(0.0, NSDecimalNumber(decimal: target / current).doubleValue)))
                        .tint(Brand.accent)
                }
                Text("日均成本越低，表示每天的使用成本越接近或低于目标。")
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)
            }
        }
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Text("删除资产")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(Brand.destructive)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Brand.destructive.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("删除资产，需要确认")
        .padding(.top, 4)
    }

    private func setStatus(_ status: AssetStatus) {
        guard asset.status != status else { return }
        asset.status = status
        asset.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            errorMessage = "状态更新失败：\(error.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        AssetDetailView(asset: Asset(
            name: "示例物品",
            price: Decimal(1288),
            purchaseDate: Date().addingTimeInterval(-60 * 86400),
            category: "数码",
            status: .inUse,
            costMode: .perDay,
            iconName: "cube.box.fill",
            notes: "用于预览的示例数据。"
        ))
    }
    .modelContainer(for: Asset.self, inMemory: true)
}
