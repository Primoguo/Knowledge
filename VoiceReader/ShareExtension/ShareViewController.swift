// VoiceReader/ShareExtension/ShareViewController.swift
import UIKit
import Social
import UniformTypeIdentifiers
import SwiftData

/// Share Extension 入口：接收 Safari 分享的网页内容
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedContent()
    }

    private func handleSharedContent() {
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        for item in inputItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // 优先处理 URL（Safari 分享网页链接）
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] urlItem, error in
                        guard let self else { return }
                        if let url = urlItem as? URL {
                            self.saveWebPage(url: url)
                        } else {
                            self.completeRequest()
                        }
                    }
                    return
                }

                // 处理纯文本
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] textItem, error in
                        guard let self else { return }
                        if let text = textItem as? String {
                            self.saveText(text: text)
                        } else {
                            self.completeRequest()
                        }
                    }
                    return
                }
            }
        }

        // 没有匹配的附件类型
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.completeRequest()
        }
    }

    // MARK: - 保存到 App 共享容器

    private func saveWebPage(url: URL) {
        // 通过 App Group 共享容器传递数据
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.voicereader.app") else {
            completeRequest()
            return
        }

        sharedDefaults.set(url.absoluteString, forKey: "pendingShareURL")
        sharedDefaults.synchronize()

        DispatchQueue.main.async { [weak self] in
            self?.showSuccessAndComplete()
        }
    }

    private func saveText(text: String) {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.voicereader.app") else {
            completeRequest()
            return
        }

        sharedDefaults.set(text, forKey: "pendingShareText")
        sharedDefaults.synchronize()

        DispatchQueue.main.async { [weak self] in
            self?.showSuccessAndComplete()
        }
    }

    private func showSuccessAndComplete() {
        // 显示成功提示
        let alert = UIAlertController(
            title: "已添加",
            message: "内容已发送到挠荔枝，请打开 App 查看",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "好的", style: .default) { [weak self] _ in
            self?.completeRequest()
        })
        present(alert, animated: true)
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
