// Knowledge/Views/APIKeyConfigView.swift
import SwiftUI

/// API Key 配置页面
struct APIKeyConfigView: View {
    @State private var apiKey: String = ""
    @State private var showSaved = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("请输入阿里云 DashScope API Key", text: $apiKey)
                        .font(.system(.body, design: .monospaced))
                        .submitLabel(.done)
                } header: {
                    Text("阿里云 DashScope API Key")
                } footer: {
                    Text("用于 AI 总结、CosyVoice 语音合成和语音克隆功能。可在阿里云 DashScope 控制台获取。")
                }

                Section {
                    Button(action: saveAndDismiss) {
                        HStack {
                            Spacer()
                            Label("保存", systemImage: "checkmark")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("如何获取 API Key？")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text("1. 访问 dashscope.aliyun.com\n2. 登录阿里云账号\n3. 进入「API Key 管理」\n4. 创建并复制 API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                apiKey = UserDefaults.standard.string(forKey: "dashscope_api_key") ?? ""
            }
        }
    }

    private func saveAndDismiss() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: "dashscope_api_key")
        dismiss()
    }
}

#Preview {
    APIKeyConfigView()
}
