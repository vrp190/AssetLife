import SwiftUI
import SwiftData

/// 资产总览页：总览卡、状态筛选、排序、双列网格、新增按钮。
struct AssetOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Asset.purchaseDate, order: .reverse) private var allAssets: [Asset]

    @State private var searchText = ""
    @State private var isSearching = false
    @State private var statusFilter: AssetStatus? = nil
    @State private var sortOption: AssetSortOption = .purchaseDateDesc
    @State private var editingAsset: Asset? = nil
    @State private var isCreating = false
    @State private var selectedAsset: Asset? = nil

    private let viewModel = AssetListViewModel()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    private var realAssets: [Asset] {
        allAssets.filter { $0.kind == .asset }
    }

    private var summary: AssetSummary {
        viewModel.summary(allAssets)
    }

    private var visibleAssets: [Asset] {
        viewModel.visibleAssets(
            realAssets,
            searchText: searchText,
            statusFilter: statusFilter,
            sortOption: sortOption
        )
    }

    private var isFiltering: Bool {
        statusFilter != nil || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isSearching {
                    searchField
                }

                SummaryCard(
                    summary: summary,
                    totalWishBudget: viewModel.wishlistSummary(allAssets).budget
                )

                StatusFilterBar(selection: $statusFilter, counts: [
                    nil: realAssets.count,
                    .inUse: summary.inUseCount,
                    .retired: summary.retiredCount,
                    .sold: summary.soldCount,
                ])

                sortRow

                if visibleAssets.isEmpty {
                    emptyContent
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(visibleAssets) { asset in
                            AssetCardView(asset: asset)
                                .onTapGesture {
                                    selectedAsset = asset
                                }
                                .accessibilityElement()
                                .accessibilityLabel("\(asset.name)，\(asset.status.title)，购入 \(MoneyFormatter.string(asset.price))")
                                .accessibilityHint("双击查看详情")
                                .accessibilityAddTraits(.isButton)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Brand.background.ignoresSafeArea())
        .navigationTitle("格物")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSearching.toggle()
                        if !isSearching { searchText = "" }
                    }
                } label: {
                    Image(systemName: isSearching ? "xmark.circle.fill" : "magnifyingglass")
                }
                .accessibilityLabel(isSearching ? "关闭搜索" : "搜索资产")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Brand.accentDeep)
                }
                .accessibilityLabel("新增资产")
            }
        }
        .sheet(isPresented: $isCreating) {
            AssetEditorView(asset: nil, defaultKind: .asset, store: SwiftDataAssetStore(context: modelContext))
                .environment(\.modelContext, modelContext)
        }
        .sheet(item: $editingAsset) { asset in
            AssetEditorView(asset: asset, defaultKind: .asset, store: SwiftDataAssetStore(context: modelContext))
                .environment(\.modelContext, modelContext)
        }
        .navigationDestination(item: $selectedAsset) { asset in
            AssetDetailView(asset: asset)
                .environment(\.modelContext, modelContext)
        }
    }

    // MARK: - 子视图

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Brand.secondaryText)
            TextField("搜索名称、类别或标签", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Brand.secondaryText)
                }
                .accessibilityLabel("清空搜索")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Brand.cardStroke, lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private var sortRow: some View {
        HStack {
            Text("\(visibleAssets.count) 件资产")
                .font(.subheadline)
                .foregroundStyle(Brand.secondaryText)
            Spacer()
            Menu {
                Picker("排序方式", selection: $sortOption) {
                    ForEach(AssetSortOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                Label("排序", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(Brand.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Brand.cardStroke, lineWidth: 1))
            }
            .accessibilityLabel("排序方式")
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var emptyContent: some View {
        if isFiltering {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "没有匹配的资产",
                message: "试试其他关键词，或切换状态筛选。"
            )
            .padding(.vertical, 40)
        } else {
            EmptyStateView(
                systemImage: "shippingbox.fill",
                title: "还没有资产",
                message: "记录第一件物品，开始了解你的日均成本。",
                actionTitle: "添加第一件资产",
                action: { isCreating = true }
            )
            .padding(.vertical, 40)
        }
    }
}

#Preview {
    NavigationStack {
        AssetOverviewView()
    }
    .modelContainer(for: Asset.self, inMemory: true)
}
