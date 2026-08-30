import SwiftUI

private enum TagManagementRoute: Equatable {
    case overview
    case addTag
    case editTag(String)
}

struct TagManagementView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let controller: TimerController
    let onBack: (() -> Void)?

    @State private var route = TagManagementRoute.overview
    @State private var selectedTag: String?
    @State private var confirmsDeleteTag = false

    init(controller: TimerController, onBack: (() -> Void)? = nil) {
        self.controller = controller
        self.onBack = onBack
    }

    var body: some View {
        Group {
            switch route {
            case .overview:
                TagsOverview(
                    controller: controller,
                    onBack: close,
                    onAdd: { route = .addTag },
                    onEdit: { route = .editTag($0) }
                )
            case .addTag:
                TagEditView(controller: controller, originalName: nil) {
                    route = .overview
                }
            case let .editTag(tag):
                TagEditView(
                    controller: controller,
                    originalName: tag,
                    onBack: { route = .overview },
                    onDelete: {
                        selectedTag = tag
                        confirmsDeleteTag = true
                    }
                )
            }
        }
        .padding(14)
        .frame(width: 380, height: 272)
        .background(FlowPalette.window)
        .alert(deletionTitle, isPresented: $confirmsDeleteTag) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                guard let selectedTag else { return }
                controller.removeTag(selectedTag)
                self.selectedTag = nil
                route = .overview
            }
        } message: {
            Text(deletionMessage)
        }
    }

    private var deletionTitle: String {
        String(
            format: String(localized: "删除标签 \"%@\"？"),
            selectedTag ?? ""
        )
    }

    private var deletionMessage: String {
        guard let selectedTag else { return String(localized: "此操作不能撤销。") }
        let usageCount = controller.tagUsageCount(selectedTag)
        if usageCount == 1 {
            return String(localized: "此标签在 1 个会话中使用。该会话将失去此标签。")
        }
        if usageCount > 1 {
            return String(
                format: String(localized: "此标签在 %lld 个会话中使用。这些会话将失去此标签。"),
                usageCount
            )
        }
        return String(localized: "此操作不能撤销。")
    }

    private func close() {
        if let onBack {
            onBack()
        } else {
            dismissWindow(id: "tags")
        }
    }
}

private struct TagsOverview: View {
    let controller: TimerController
    let onBack: () -> Void
    let onAdd: () -> Void
    let onEdit: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            TagNavigationHeader(title: "标签", onBack: onBack)

            Text("使用标签对会话进行分类和整理。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                if controller.tagSettings.tags.isEmpty {
                    Text("无标签")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(controller.tagSettings.tags, id: \.self) { tag in
                                Button {
                                    onEdit(tag)
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(FlowPalette.tag(controller.tagSettings.colorHex(for: tag)))
                                        Text(tag)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(
                                    format: String(localized: "edit_tag_accessibility_format"),
                                    tag
                                ))

                                if tag != controller.tagSettings.tags.last {
                                    Divider().padding(.leading, 33)
                                }
                            }
                        }
                    }
                }
            }
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            HStack {
                Spacer()
                Button(action: onAdd) {
                    Label("添加", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(FlowPalette.focus)
            }
        }
    }
}

private struct TagEditView: View {
    let controller: TimerController
    let originalName: String?
    let onBack: () -> Void
    let onDelete: (() -> Void)?

    @State private var title: String
    @State private var colorHex: String

    init(
        controller: TimerController,
        originalName: String?,
        onBack: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.controller = controller
        self.originalName = originalName
        self.onBack = onBack
        self.onDelete = onDelete
        _title = State(initialValue: originalName ?? "")
        _colorHex = State(
            initialValue: originalName.map(controller.tagSettings.colorHex(for:))
                ?? SessionTagSettings.palette[controller.tagSettings.tags.count % SessionTagSettings.palette.count]
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            TagNavigationHeader(title: "标签", onBack: onBack)

            VStack(alignment: .leading, spacing: 8) {
                Text("标题")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("标题", text: $title)
                    .textFieldStyle(.roundedBorder)

                Text("颜色")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                HStack(spacing: 14) {
                    ForEach(Array(SessionTagSettings.palette.enumerated()), id: \.offset) { index, color in
                        Button {
                            colorHex = color
                        } label: {
                            Image(systemName: colorHex == color ? "checkmark.circle.fill" : "circle.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(FlowPalette.tag(color))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(
                            format: String(localized: "tag_color_accessibility_format"),
                            index + 1
                        ))
                        .accessibilityValue(
                            colorHex == color
                                ? String(localized: "已选择")
                                : String(localized: "未选择")
                        )
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Spacer(minLength: 0)

            HStack {
                if let onDelete {
                    Button("删除", role: .destructive, action: onDelete)
                }
                Spacer()
                Button("取消", action: onBack)
                Button("保存", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
            && !controller.tagSettings.tags.contains(where: { tag in
                tag != originalName && tag.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
            })
    }

    private func save() {
        if let originalName {
            controller.updateTag(originalName, name: title, colorHex: colorHex)
        } else {
            controller.addTag(title, colorHex: colorHex)
        }
        onBack()
    }
}

private struct TagNavigationHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            Spacer()
            Text(LocalizedStringKey(title))
                .font(.headline)
            Spacer()
                .frame(width: 20)
        }
    }
}
