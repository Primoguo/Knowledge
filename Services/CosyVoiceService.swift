// Knowledge/Services/CosyVoiceService.swift
import Foundation

/// 阿里云 DashScope CosyVoice 语音合成服务
/// 支持：预设音色 TTS + 语音克隆
final class CosyVoiceService {
    static let shared = CosyVoiceService()

    private let apiKey: String
    private let baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/tts/cosyvoice-synthesis"
    private let cloneURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/tts/cosyvoice-clone"
    private let session: URLSession

    private init() {
        self.session = URLSession.shared
        self.apiKey = UserDefaults.standard.string(forKey: "dashscope_api_key") ?? ""
    }

    // MARK: - TTS 合成

    /// 使用 CosyVoice 将文本转为语音
    /// - Parameters:
    ///   - text: 要合成的文本（单次最多 1000 字符）
    ///   - voiceId: 音色 ID（预设或克隆的 voice_id）
    ///   - rate: 语速（0.5 ~ 2.0）
    /// - Returns: 音频数据（PCM/WAV）
    func synthesize(text: String, voiceId: String, rate: Float = 1.0) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw CosyVoiceError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "cosyvoice-v1",
            "input": [
                "text": text
            ],
            "parameters": [
                "voice": voiceId,
                "format": "mp3",
                "sample_rate": 24000,
                "speech_rate": rate
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CosyVoiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CosyVoiceError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CosyVoiceError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        // 解析响应，获取音频数据
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any] else {
            throw CosyVoiceError.invalidResponse
        }

        // 如果返回的是音频 URL，则下载
        if let audioURL = output["audio_url"] as? String,
           let url = URL(string: audioURL) {
            let (audioData, _) = try await session.data(from: url)
            return audioData
        }

        // 如果直接返回 base64 编码的音频
        if let audioBase64 = output["audio"] as? String,
           let audioData = Data(base64Encoded: audioBase64) {
            return audioData
        }

        throw CosyVoiceError.noAudioData
    }

    // MARK: - 语音克隆

    /// 克隆声音（上传参考音频）
    /// - Parameters:
    ///   - audioData: 参考音频数据（WAV/MP3，10-30秒）
    ///   - voiceName: 自定义音色名称
    /// - Returns: 克隆后的 voice_id
    func cloneVoice(audioData: Data, voiceName: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw CosyVoiceError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: cloneURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let audioBase64 = audioData.base64EncodedString()

        let body: [String: Any] = [
            "model": "cosyvoice-v1",
            "input": [
                "audio": audioBase64
            ],
            "parameters": [
                "voice_name": voiceName
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CosyVoiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CosyVoiceError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CosyVoiceError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let voiceId = output["voice_id"] as? String else {
            throw CosyVoiceError.invalidResponse
        }

        return voiceId
    }

    // MARK: - 音色试听

    /// 获取音色试听音频
    /// - Parameters:
    ///   - voiceId: 音色 ID
    ///   - sampleText: 试听文本
    /// - Returns: 音频数据
    func previewVoice(voiceId: String, sampleText: String = "欢迎使用 CosyVoice 语音合成服务") async throws -> Data {
        return try await synthesize(text: sampleText, voiceId: voiceId)
    }
}

// MARK: - 分段合成辅助

extension CosyVoiceService {
    /// 分段合成并拼接（用于长文本）
    /// - Parameters:
    ///   - segments: 文本段落数组
    ///   - voiceId: 音色 ID
    ///   - onProgress: 进度回调（completed/total）
    /// - Returns: 拼接后的完整音频数据
    func synthesizeSegments(
        segments: [String],
        voiceId: String,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> Data {
        var allAudioData = Data()

        for (index, segment) in segments.enumerated() {
            let audio = try await synthesize(text: segment, voiceId: voiceId)
            allAudioData.append(audio)
            onProgress(index + 1, segments.count)

            // 段间延迟，避免请求过快
            if index < segments.count - 1 {
                try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            }
        }

        return allAudioData
    }
}

// MARK: - Errors

enum CosyVoiceError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidResponse
    case noAudioData
    case apiError(statusCode: Int, message: String)
    case audioTooShort
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中配置阿里云 API Key"
        case .invalidAPIKey:
            return "API Key 无效，请检查后重试"
        case .invalidResponse:
            return "服务器返回数据异常"
        case .noAudioData:
            return "未获取到音频数据"
        case .apiError(let code, let msg):
            return "请求失败（\(code)）：\(msg)"
        case .audioTooShort:
            return "录音时长不足，请录制至少 5 秒"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
