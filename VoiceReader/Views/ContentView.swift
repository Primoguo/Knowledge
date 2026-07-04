// VoiceReader/Views/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var speakerVM = SpeakerViewModel()
    @StateObject private var errorHandler = ErrorHandler.shared
    @StateObject private var shareHandler = ShareExtensionHandler.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showShareAlert = false
    @State private var shareAlertMsg = ""
    @State private var isLoadingShare = false

    private let extractor = TextExtractionService()

    var body: some View {
        TabView {
            DocumentListView(speakerVM: speakerVM)
                .tabItem { Label("书库", systemImage: "books.vertical.fill") }
            PlayerView(speakerVM: speakerVM)
                .tabItem { Label("正在播放", systemImage: "headphones") }
            SettingsView(speakerVM: speakerVM)
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(.blue)
        .alert(item: $errorHandler.currentAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("确定")))
        }
        .alert("来自分享", isPresented: $showShareAlert) {
            Button("取消", role: .cancel) {}
            Button("添加") {
                Task { await handleShareContent() }
            }
        } message: {
            Text(shareAlertMsg)
        }
        .onAppear {
            shareHandler.checkPendingContent()
            handlePendingShare()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            shareHandler.checkPendingContent()
            handlePendingShare()
        }
    }

    private func handlePendingShare() {
        if let url = shareHandler.pendingURL {
            shareAlertMsg = "检测到网页链接：\n\(url)\n\n是否添加到书库？"
            showShareAlert = true
        } else if let text = shareHandler.pendingText {
            let preview = String(text.prefix(100))
            shareAlertMsg = "检测到分享文本：\n\(preview)\(text.count > 100 ? "..." : "")\n\n是否添加到书库？"
            showShareAlert = true
        }
    }

    private func handleShareContent() async {
        isLoadingShare = true
        defer { isLoadingShare = false }

        do {
            if let urlString = shareHandler.pendingURL {
                let result = try await extractor.extractFromWebPage(urlString: urlString)
                let doc = Document(
                    title: result.title,
                    fileName: urlString,
                    fileType: .webpage,
                    extractedText: result.text
                )
                await MainActor.run {
                    modelContext.insert(doc)
                    try? modelContext.save()
                }
                shareHandler.pendingURL = nil
            } else if let text = shareHandler.pendingText {
                let title = "分享文本 \(Date().formatted(date: .abbreviated, time: .shortened))"
                let doc = Document(
                    title: title,
                    fileName: "shared.txt",
                    fileType: .txt,
                    extractedText: text
                )
                await MainActor.run {
                    modelContext.insert(doc)
                    try? modelContext.save()
                }
                shareHandler.pendingText = nil
            }
        } catch {
            await MainActor.run {
                shareAlertMsg = "导入失败：\(error.localizedDescription)"
                showShareAlert = true
            }
        }
    }
}
