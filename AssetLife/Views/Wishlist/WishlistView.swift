import SwiftUI
import SwiftData

/// 心愿清单页：预算总览、心愿列表、新增、标记已购买并转换为资产。
struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.purchaseDate, order: .reverse) private var allAssets: [Asset]

    @State private var isCreating = false
    @State private var editingAsset: Asset? = nil
    @State private var convertingWish: Asset? = nil
    @State private var errorMessage: String?
    @State private var showError = false

    private let viewModel = AssetListViewModel()

    private var wishes: [Asset] {
        allAssets.filter { $0.kind == .wishlist }
    }

    private var wishSummary: (count: Int, budget: Decimal) {
        viewModel.wishlistSummary(allAssets)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                budgetCard
                if wishes.isEmpty {
                    EmptyStateView(
                        systemImage: "star.fill",
                        title: "还没有心愿",
                        message: "把想买的东西记下来，购入后一键转为资产。",
                        actionTitle: "添加第一个心愿",
                        action: { isCreating = true }
                    )
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(wishes) { wish in
                            wishRow(wish)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("心愿")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Brand.accentDeep)
                }
                .accessibilityLabel("新增心愿")
            }
        }
        .sheet(isPresented: $isCreating) {
            AssetEditorView(asset: nil, defaultKind: .wishlist, store: SwiftDataAssetStore(context: modelContext))
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $editingAsset) { wish in
            AssetEditorView(asset: wish, defaultKind: .wishlist, store: SwiftDataAssetStore(context: modelContext))
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $convertingWish) { wish in
            ConvertWishSheet(wish: wish) { actualDate in
                convert(wish, actualDate: actualDate)
            }
        }
        .alert("操作失败", isPresented: $showError) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 子视图

    private var budgetCard: some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("心愿总数")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    Text("\(wishSummary.count)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.primaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("预算总额")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    Text(MoneyFormatter.string(wishSummary.budget))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.accentDeep)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func wishRow(_ wish: Asset) -> some View {
        CardContainer {
            HStack(spacing: 12) {
                IconBadge(systemImage: wish.iconName, size: 44, tint: Brand.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(wish.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primaryText)
                        .lineLimit(2)
                    Text(MoneyFormatter.string(wish.price))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Brand.accentDeep)
                    Text("计划 \(DateFormatterBox.dateString(wish.purchaseDate))")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                    if !wish.category.isEmpty {
                        Text(wish.category)
                            .font(.caption2)
                            .foregroundStyle(Brand.secondaryText)
                    }
                }
                Spacer()
                VStack(spacing: 8) {
                    Button {
                        convertingWish = wish
                    } label: {
                        Text("已购买")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Brand.accent)
                            .foregroundStyle(Brand.primaryText)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("将\(wish.name)标记为已购买")

                    Button {
                        editingAsset = wish
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Brand.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("编辑心愿")
                }
            }
        }
    }

    // MARK: - 心愿转资产

    private func convert(_ wish: Asset, actualDate: Date) {
        let asset = Asset(
            name: wish.name,
            price: wish.price,
            purchaseDate: actualDate,
            category: wish.category,
            status: .inUse,
            kind: .asset,
            costMode: .perDay,
            useCount: 0,
            iconName: wish.iconName,
            notes: wish.notes,
            tags: wish.tags,
            createdAt: Date(),
            updatedAt: Date(),
            targetMode: wish.targetMode,
            targetValue: wish.targetValue,
            targetDate: wish.targetDate,
            isDemoData: false
        )
        do {
            let store = SwiftDataAssetStore(context: modelContext)
            try store.addAsset(asset)
            try store.delete(wish)
        } catch {
            errorMessage = "转换失败：\(error.localizedDescription)"
            showError = true
        }
    }
}

/// 心愿转资产：补充实际购买日期。
struct ConvertWishSheet: View {
    let wish: Asset
    let onConvert: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var actualDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            IconBadge(systemImage: wish.iconName, size: 40, tint: Brand.accent)
                            Text(wish.name)
                                .font(.headline)
                                .foregroundStyle(Brand.primaryText)
                            Spacer()
                            Text(MoneyFormatter.string(wish.price))
                                .font(.headline)
                                .foregroundStyle(Brand.accentDeep)
                        }
                        Text("转换为正式资产后，将按实际购买日期开始累计持有天数。")
                            .font(.caption)
                            .foregroundStyle(Brand.secondaryText)
                    }
                }

                CardContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("实际购买日期")
                            .font(.headline)
                            .foregroundStyle(Brand.primaryText)
                        DatePicker(
                            "实际购买日期",
                            selection: $actualDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Brand.accentDeep)
                        .labelsHidden()
                    }
                }

                PrimaryButton(title: "转换为资产", systemImage: "arrow.right.circle.fill") {
                    onConvert(actualDate)
                    dismiss()
                }
            }
            .padding(16)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        WishlistView()
    }
    .modelContainer(for: Asset.self, inMemory: true)
}
