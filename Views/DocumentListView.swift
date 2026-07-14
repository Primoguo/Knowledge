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
                        VStack(alignment: .leading, spacing: 32) {
                            // 继续收听（有进度的文档）
                            if !recentDocs.isEmpty {
                                continueListeningSection
                            }

                            // 全部文档
                            VStack(alignment: .leading, spacing: 16) {
                                if !recentDocs.isEmpty {
                                    Text("全部文档")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 20)
                                }

                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)
                                    ],
                                    spacing: 10
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
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("书库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showURLInput = true } label: {
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                        }
                        Button { showPicker = true } label: {
                            Image(systemName: "plus")
                                .foregroundColor(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("继续收听")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
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
                .padding(.horizontal, 20)
            }
        }
    }

    private func continueListeningCard(doc: Document, isPlaying: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text(doc.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .foregroundColor(.primary)

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.08))
                        .frame(height: 2)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: geo.size.width * doc.progress, height: 2)
                }
            }
            .frame(height: 2)

            // 进度百分比
            Text("\(Int(doc.progress * 100))%")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 160)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isPlaying ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.12), lineWidth: isPlaying ? 1.5 : 0.5)
        )
    }

    private func formatLen(_ len: Int) -> String {
        if len >= 10000 { return String(format: "%.1f万字", Double(len) / 10000.0) }
        else if len >= 1000 { return String(format: "%.1f千字", Double(len) / 1000.0) }
        return "\(len)字"
    }

    private var emptyView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // 荔枝吉祥物
            LycheeMascotView(size: 80, state: .waving)
            
            VStack(spacing: 8) {
                Text("书库是空的")
                    .font(.system(size: 17, weight: .medium))
                Text("导入文档开始你的听书之旅")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 10) {
                Button {
                    showPicker = true
                } label: {
                    Label("导入文档", systemImage: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                
                Button {
                    showURLInput = true
                } label: {
                    Label("添加网页", systemImage: "link")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
            .padding(.horizontal, 48)
            
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
