// VoiceReader/Views/DocumentListView.swift
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
                    List {
                        ForEach(documents) { doc in
                            DocumentRowView(
                                document: doc,
                                isPlaying: speakerVM.currentDocument?.id == doc.id && speakerVM.state == .playing
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                speakerVM.loadDocument(doc)
                                speakerVM.play()
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteDoc(doc) } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("书库")
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

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 60)).foregroundColor(.secondary)
            Text("还没有文档").font(.title2).foregroundColor(.secondary)
            Text("点击右上角 + 导入文档").font(.subheadline).foregroundColor(.secondary)
            HStack(spacing: 16) {
                Button { showPicker = true } label: {
                    Label("导入文档", systemImage: "square.and.arrow.down.fill")
                        .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.blue).foregroundColor(.white).clipShape(Capsule())
                }
                Button { showURLInput = true } label: {
                    Label("添加网页", systemImage: "link")
                        .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Color.teal).foregroundColor(.white).clipShape(Capsule())
                }
            }
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
