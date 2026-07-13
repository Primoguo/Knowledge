// Knowledge/Views/DocumentListView.swift
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentListView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Document.lastOpenedDate, order: .reverse) private var documents: [Document]
    @State private var showPicker = false
    @State private var alertMsg = ""
    @State private var showAlert = false
    @State private var showURLInput = false
    @State private var urlString = ""
    @State private var isLoadingURL = false

    private let extractor = TextExtractionService()

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // 继续收听（有进度的文档）
                            if !recentDocs.isEmpty {
                                continueListeningSection
                            }

                            // 全部文档网格
                            if !recentDocs.isEmpty {
                                Text("全部文档")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                            }

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)
                                ],
                                spacing: 12
                            ) {
                                ForEach(documents) { doc in
                                    let playing = speakerVM.currentDocument?.id == doc.id && speakerVM.state == .playing

                                    Button {
                                        HapticService.shared.playPause()
                                        speakerVM.loadDocument(doc)
                                        speakerVM.play()
                                    } label: {
                                        DocumentCardView(document: doc, isPlaying: playing)
                                    }
                                    .buttonStyle(PressableStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            deleteDoc(doc)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 8)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("书库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showURLInput = true } label: {
                            Image(systemName: "link")
                        }
                        Button { showPicker = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in importFile(url) }
            }
            .alert("添加网页", isPresented: $showURLInput) {
                TextField("粘贴网页链接", text: $urlString)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("取消", role: .cancel) { urlString = "" }
                Button("添加") { Task { await importWebPage() } }
                    .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isLoadingURL)
            } message: {
                Text(isLoadingURL ? "正在加载网页..." : "粘贴链接后点击添加，系统将自动提取网页文本")
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: { Text(alertMsg) }
        }
    }

    // MARK: - Continue Listening

    /// 有收听进度的文档（最多显示 5 个）
    private var recentDocs: [Document] {
        documents.filter { $0.progress > 0 }.prefix(5).map { $0 }
    }

    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("继续收听")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recentDocs) { doc in
                        let playing = speakerVM.currentDocument?.id == doc.id && speakerVM.state == .playing

                        Button {
                            HapticService.shared.playPause()
                            speakerVM.loadDocument(doc)
                            speakerVM.play()
                        } label: {
                            continueListeningCard(doc: doc, isPlaying: playing)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func continueListeningCard(doc: Document, isPlaying: Bool) -> some View {
        HStack(spacing: 10) {
            // 小图标
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor(doc.fileType.iconColor).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: doc.fileType.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor(doc.fileType.iconColor))
            }

            // 标题 + 进度
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(isPlaying ? .accentColor : .primary)

                // 迷你进度条
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 2)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: geo.size.width * doc.progress, height: 2)
                        }
                    }
                    .frame(width: 50, height: 2)

                    Text("\(Int(doc.progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)

            // 播放状态 / 箭头
            if isPlaying {
                Image(systemName: "waveform")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
                    .symbolEffect(.variableColor.iterative)
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func iconColor(_ name: String) -> Color {
        switch name {
        case "red": return .red; case "blue": return .blue; case "green": return .green
        case "orange": return .orange; case "purple": return .purple; case "teal": return .teal
        default: return .gray
        }
    }

    private func formatLen(_ len: Int) -> String {
        if len >= 10000 { return String(format: "%.1f万字", Double(len) / 10000.0) }
        else if len >= 1000 { return String(format: "%.1f千字", Double(len) / 1000.0) }
        return "\(len)字"
    }

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // 品牌化图标
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "book.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 8) {
                Text("书库还是空的")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("导入文档，开始你的听书之旅")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 14) {
                Button {
                    showPicker = true
                } label: {
                    Label("导入文档", systemImage: "square.and.arrow.down.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                Button {
                    showURLInput = true
                } label: {
                    Label("添加网页", systemImage: "link")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.08))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
        }
    }

    private func importFile(_ url: URL) {
        let title = (url.lastPathComponent as NSString).deletingPathExtension
        do {
            let text = try extractor.extractText(from: url)
            let docType = DocumentType(fileExtension: url.pathExtension.lowercased())
            let doc = Document(title: title, fileName: url.lastPathComponent, fileType: docType, extractedText: text)
            modelContext.insert(doc)
            try modelContext.save()
        } catch {
            alertMsg = error.localizedDescription
            showAlert = true
        }
    }

    private func importWebPage() async {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isLoadingURL = true
        defer { isLoadingURL = false }

        do {
            let result = try await extractor.extractFromWebPage(urlString: trimmed)
            let doc = Document(
                title: result.title,
                fileName: trimmed,
                fileType: .webpage,
                extractedText: result.text
            )
            await MainActor.run {
                modelContext.insert(doc)
                try? modelContext.save()
                urlString = ""
            }
        } catch {
            await MainActor.run {
                alertMsg = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func deleteDoc(_ doc: Document) {
        if speakerVM.currentDocument?.id == doc.id { speakerVM.stop() }
        modelContext.delete(doc)
        try? modelContext.save()
    }
}
