// Knowledge/Services/ServerAPIClient.swift
import Foundation

/// 服务器 API 客户端 — 与你的中转服务器通信
/// 所有 AI 请求都通过服务器中转，API Key 仅存储在服务器端
final class ServerAPIClient {
    static let shared = ServerAPIClient()

    // MARK: - Configuration

    // 服务器地址：naolizhi.cn 中转服务（DeepSeek AI + Edge TTS）
    static let baseURL = "https://naolizhi.cn/api"

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - AI Summary

    /// 请求 AI 总结
    func requestSummary(text: String, systemPrompt: String) async throws -> String {
        let body: [String: Any] = [
            "text": String(text.prefix(8000)),
            "systemPrompt": systemPrompt
        ]
        return try await post(endpoint: "/summary", body: body, extractContent: true)
    }

    // MARK: - AI Companion

    /// 请求 AI 伴读对话
    func requestCompanion(question: String, context: String, history: [[String: String]], systemPrompt: String) async throws -> String {
        let body: [String: Any] = [
            "question": question,
            "context": context,
            "history": history,
            "systemPrompt": systemPrompt
        ]
        return try await post(endpoint: "/companion", body: body, extractContent: true)
    }

    // MARK: - CosyVoice TTS

    /// 请求 CosyVoice 语音合成
    func requestTTS(text: String, voiceId: String, rate: Float) async throws -> Data {
        let body: [String: Any] = [
            "text": text,
            "voice_id": voiceId,
            "rate": rate
        ]

        var request = buildRequest(endpoint: "/tts", body: body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerAPIError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)

        // TTS 返回音频数据（binary）
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           contentType.contains("audio") {
            return data
        }

        // 也可能返回 JSON 中包含音频 URL 或 base64
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let audioURL = json["audio_url"] as? String,
               let url = URL(string: audioURL) {
                let (audioData, _) = try await URLSession.shared.data(from: url)
                return audioData
            }
            if let audioBase64 = json["audio"] as? String,
               let audioData = Data(base64Encoded: audioBase64) {
                return audioData
            }
        }

        throw ServerAPIError.noAudioData
    }

    /// 请求语音克隆
    func requestVoiceClone(audioData: Data, voiceName: String) async throws -> String {
        let body: [String: Any] = [
            "audio": audioData.base64EncodedString(),
            "voice_name": voiceName
        ]
        return try await post(endpoint: "/voice-clone", body: body, extractField: "voice_id")
    }

    // MARK: - Private Helpers

    private func buildRequest(endpoint: String, body: [String: Any]) -> URLRequest {
        let url = URL(string: "\(Self.baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 可选：添加 App 身份验证 Token（防止接口被滥用）
        // request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    @discardableResult
    private func post(endpoint: String, body: [String: Any], extractContent: Bool) async throws -> String {
        var request = buildRequest(endpoint: endpoint, body: body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerAPIError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ServerAPIError.invalidResponse
        }

        // 通用提取 result 字段（DeepSeek 中转服务返回格式）
        if let result = json["result"] as? String {
            return result
        }

        // 兼容 content 字段
        if let content = json["content"] as? String {
            return content
        }

        // 兼容 DashScope 原始格式
        if let output = json["output"] as? [String: Any],
           let choices = output["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw ServerAPIError.invalidResponse
    }

    private func post(endpoint: String, body: [String: Any], extractField: String) async throws -> String {
        var request = buildRequest(endpoint: endpoint, body: body)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerAPIError.invalidResponse
        }

        try validateResponse(httpResponse, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json[extractField] as? String else {
            throw ServerAPIError.invalidResponse
        }

        return value
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200:
            return
        case 401, 403:
            throw ServerAPIError.unauthorized
        case 402, 429:
            throw ServerAPIError.quotaExceeded
        default:
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ServerAPIError.serverError(statusCode: response.statusCode, message: msg)
        }
    }
}

// MARK: - Errors

enum ServerAPIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case quotaExceeded
    case noAudioData
    case serverError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回数据异常，请稍后重试"
        case .unauthorized:
            return "请确认已订阅 Premium"
        case .quotaExceeded:
            return "本月使用次数已达上限，请升级套餐或下月再试"
        case .noAudioData:
            return "未获取到音频数据"
        case .serverError(let code, let msg):
            return "服务异常（\(code)），请稍后重试"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
