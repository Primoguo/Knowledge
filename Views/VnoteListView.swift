// Knowledge/Views/VnoteListView.swift
import SwiftUI
import SwiftData

/// Vnote 语音速记列表页
struct VnoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VnoteEntry.updatedAt, order: .reverse) private var entries: [VnoteEntry]
    @State private var showRecorder = false
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
                            NavigationLink(destination: VnoteDetailView(entry: entry)) {
                                entryRow(entry)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Vnote")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRecorder = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索速记...")
            .sheet(isPresented: $showRecorder) {
                VnoteRecorderView()
            }
        }
    }

    // MARK: - Filtered Entries

    private var filteredEntries: [VnoteEntry] {
        var result = entries
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.transcription.lowercased().contains(q) ||
                $0.aiContent.lowercased().contains(q)
            }
        }
        return result
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "全部", icon: "waveform")
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
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.primary : Color.secondary.opacity(0.08))
            )
        }
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: VnoteEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // 分类标签
                Image(systemName: entry.category.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(categoryColor(entry.category))

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

                // 时长
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(entry.durationText)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            // 标题
            Text(entry.title.isEmpty ? "未命名速记" : entry.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            // 预览
            Text(entry.preview)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)

            // 底部信息
            HStack(spacing: 12) {
                Text(entry.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))

                if entry.isPremiumSTT {
                    Label("高亮", systemImage: "text.magnifyingglass")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
                }

                if entry.isSyncedToKnowledge {
                    Label("已沉淀", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green.opacity(0.7))
                }
            }
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
            Image(systemName: "mic.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.3))

            Text("还没有语音速记")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("点击右上角麦克风开始录音\n录音会自动转为文字")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)

            Button {
                showRecorder = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                    Text("开始录音")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Capsule().fill(Color.primary))
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = filteredEntries[index]
            // 删除录音文件
            if let url = entry.audioFileURL {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }
}

// MARK: - Placeholder Views (后续实现)

/// 速记详情页占位（录音回放 + AI 内容 + 转写文字）
struct VnoteDetailView: View {
    let entry: VnoteEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部
                HStack {
                    Image(systemName: entry.category.iconName)
                        .foregroundColor(categoryColor(entry.category))
                    Text(entry.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.durationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // AI 生成内容
                if !entry.aiContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI 整理")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.aiContent)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
                }

                Divider()

                // 转写文本
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("转写文本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        if entry.isPremiumSTT {
                            Label("含时间戳", systemImage: "clock.badge")
                                .font(.caption2)
                                .foregroundColor(.blue.opacity(0.7))
                        }
                    }
                    Text(entry.transcription.isEmpty ? "（无转写内容）" : entry.transcription)
                        .font(.system(size: 15))
                        .foregroundColor(entry.transcription.isEmpty ? .secondary : .primary)
                        .lineSpacing(4)
                }
            }
            .padding(16)
        }
        .navigationTitle(entry.title.isEmpty ? "未命名速记" : entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func categoryColor(_ category: KnowledgeCategory) -> Color {
        switch category {
        case .meeting:  return .blue
        case .creative: return .orange
        case .todo:     return .green
        case .general:  return .gray
        }
    }
}

/// 录音页占位（后续实现录音 + STT 功能）
struct VnoteRecorderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "mic.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary.opacity(0.3))

                Text("录音功能开发中")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("录音 → 语音转文字 → AI 分类\n即将上线")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.7))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .navigationTitle("新建速记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
