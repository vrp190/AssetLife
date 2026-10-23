import SwiftUI

/// 新增 / 编辑资产（心愿）表单页。
struct AssetEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: AssetEditorViewModel

    @State private var showSymbolPicker = false
    @State private var showDiscardConfirm = false
    @State private var showValidation = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, price, useCount, targetValue, tags, notes
    }

    /// - Parameter store: 由父视图在 body 中注入（持有 modelContext），便于测试替换。
    init(asset: Asset? = nil, defaultKind: AssetKind = .asset, store: AssetStoreProtocol) {
        _viewModel = StateObject(wrappedValue: AssetEditorViewModel(
            asset: asset,
            defaultKind: defaultKind,
            store: store
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    iconSection
                    basicSection
                    categorySection
                    dateSection
                    statusSection
                    costSection
                    targetSection
                    notesSection
                    if showValidation, !viewModel.validation.isValid {
                        validationBanner
                    }
                }
                .padding(16)
            }
            .background(Brand.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { attemptDismiss() }
                        .accessibilityLabel("取消编辑")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Brand.accentDeep)
                        .accessibilityLabel("保存")
                }
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerView(selected: $viewModel.iconName)
            }
            .confirmationDialog("放弃未保存的修改？", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .alert("无法保存", isPresented: $showError) {
                Button("好") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 表单分区

    private var iconSection: some View {
        CardContainer {
            HStack(spacing: 14) {
                Button {
                    showSymbolPicker = true
                } label: {
                    IconBadge(systemImage: viewModel.iconName, size: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择图标")

                VStack(alignment: .leading, spacing: 4) {
                    Text("图标")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.primaryText)
                    Text("从精选符号中选择")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                }
                Spacer()
            }
        }
    }

    private var basicSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("基本信息")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("名称")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    TextField("例如：人体工学椅", text: $viewModel.name)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .name)
                        .padding(12)
                        .background(Brand.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.kind == .wishlist ? "预计价格（¥）" : "购入价格（¥）")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    TextField("0.00", text: $viewModel.priceText)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)
                        .padding(12)
                        .background(Brand.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("类型")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    Picker("类型", selection: $viewModel.kind) {
                        Text("资产").tag(AssetKind.asset)
                        Text("心愿").tag(AssetKind.wishlist)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var categorySection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("类别")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AssetCategory.allCases) { category in
                            let isSelected = viewModel.category == category.rawValue
                            Button {
                                viewModel.category = category.rawValue
                                viewModel.iconName = category.systemImage
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: category.systemImage)
                                        .font(.system(size: 11))
                                    Text(category.rawValue)
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(isSelected ? Brand.primaryText : Brand.secondaryText)
                                .background(isSelected ? Brand.accent : Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(isSelected ? Color.clear : Brand.cardStroke, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(category.rawValue)
                        }
                    }
                }
                TextField("自定义类别", text: $viewModel.category)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Brand.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .font(.subheadline)
            }
        }
    }

    private var dateSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.kind == .wishlist ? "计划购入日期" : "购买日期")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                DatePicker(
                    "日期",
                    selection: $viewModel.purchaseDate,
                    in: viewModel.kind == .wishlist ? ...Date().addingTimeInterval(3650 * 86400) : ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Brand.accentDeep)
                .labelsHidden()
                if viewModel.kind == .wishlist {
                    Text("心愿可以设置未来的计划购入日期。")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                } else {
                    Text("购买日期不能晚于今天。")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                }
            }
        }
    }

    private var statusSection: some View {
        Group {
            if viewModel.kind == .asset {
                CardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("状态")
                            .font(.headline)
                            .foregroundStyle(Brand.primaryText)
                        Picker("状态", selection: $viewModel.status) {
                            ForEach(AssetStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var costSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("成本计算规则")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                Picker("成本模式", selection: $viewModel.costMode) {
                    ForEach(CostMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(viewModel.costMode.detail)
                    .font(.caption2)
                    .foregroundStyle(Brand.secondaryText)

                if viewModel.costMode == .perUse {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("使用次数")
                            .font(.caption)
                            .foregroundStyle(Brand.secondaryText)
                        TextField("例如：120", text: $viewModel.useCountText)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .useCount)
                            .padding(12)
                            .background(Brand.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if viewModel.costMode == .custom {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("每日成本金额（¥）")
                            .font(.caption)
                            .foregroundStyle(Brand.secondaryText)
                        TextField("例如：5.00", text: $viewModel.targetValueText)
                            .textFieldStyle(.plain)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .targetValue)
                            .padding(12)
                            .background(Brand.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var targetSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("目标日均成本")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)
                Picker("目标模式", selection: $viewModel.targetMode) {
                    ForEach(TargetDailyCostMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch viewModel.targetMode {
                case .none:
                    Text("不设置目标。")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                case .byDate:
                    DatePicker(
                        "目标日期",
                        selection: $viewModel.targetDate,
                        in: viewModel.purchaseDate...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(Brand.accentDeep)
                    Text("目标 = 购入价 ÷ 到目标日期的天数")
                        .font(.caption2)
                        .foregroundStyle(Brand.secondaryText)
                case .custom:
                    VStack(alignment: .leading, spacing: 6) {
                        Text("目标金额（¥/天）")
                            .font(.caption)
                            .foregroundStyle(Brand.secondaryText)
                        TextField("例如：3.00", text: $viewModel.targetValueText)
                            .textFieldStyle(.plain)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Brand.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("标签与备注")
                    .font(.headline)
                    .foregroundStyle(Brand.primaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("标签（逗号分隔）")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    TextField("例如：办公, 苹果", text: $viewModel.tagsText)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .tags)
                        .padding(12)
                        .background(Brand.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("备注")
                        .font(.caption)
                        .foregroundStyle(Brand.secondaryText)
                    TextEditor(text: $viewModel.notes)
                        .focused($focusedField, equals: .notes)
                        .frame(minHeight: 72)
                        .padding(8)
                        .background(Brand.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .font(.subheadline)
                }
            }
        }
    }

    private var validationBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("请检查以下问题", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.destructive)
            ForEach(viewModel.validation.messages, id: \.self) { message in
                Text("· " + message)
                    .font(.caption)
                    .foregroundStyle(Brand.destructive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Brand.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 行为

    private func save() {
        focusedField = nil
        let result = viewModel.validate()
        showValidation = true
        guard result.isValid else { return }
        do {
            try viewModel.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func attemptDismiss() {
        if viewModel.hasUnsavedChanges {
            showDiscardConfirm = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    AssetEditorView(asset: nil, defaultKind: .asset, store: InMemoryAssetStore())
}
