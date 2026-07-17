// Knowledge/Views/KnowledgeListView.swift
import SwiftUI
import SwiftData

/// 知识库列表页 — 展示所有沉淀的知识条目
struct KnowledgeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KnowledgeEntry.updatedAt, order: .reverse) private var entries: [KnowledgeEntry]
    @State private var selectedCategory: KnowledgeCategory? = nil
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 分类筛选
                categoryFilter

                // 列表
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: KnowledgeDetailView(entry: entry)) {
                                entryRow(entry)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("知识库")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索知识...")
        }
    }

    // MARK: - Filtered Entries

    private var filteredEntries: [KnowledgeEntry] {
        var result = entries

        // 分类筛选
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // 搜索
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query)
            }
        }

        return result
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "全部", icon: "square.grid.2x2")
                ForEach(KnowledgeCategory.allCases, id: \.self) { cat in
                    filterChip(cat, label: cat.displayName, icon: cat.iconName)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(_ category: KnowledgeCategory?, label: String, icon: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? Color(.systemBackground) : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.primary : Color.secondary.opacity(0.08))
            )
        }
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: KnowledgeEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // 来源图标
                Image(systemName: entry.source.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                // 分类标签
                Text(entry.category.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundColor(.white)
                    .background(
                        Capsule()
                            .fill(categoryColor(entry.category))
                    )

                Spacer()

                // 时间
                Text(entry.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 标题
            Text(entry.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            // 预览
            Text(entry.preview)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    private func categoryColor(_ category: KnowledgeCategory) -> Color {
        switch category {
        case .meeting:  return .blue
        case .creative: return .orange
        case .todo:     return .green
        case .general:  return .gray
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))

            Text("知识库是空的")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("从文档摘要或语音速记中沉淀知识\n所有内容会汇聚在这里")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredEntries[index])
        }
        try? modelContext.save()
    }
}
