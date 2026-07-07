// Knowledge/Services/CosyVoiceService.swift
import Foundation

/// CosyVoice 语音合成服务
/// 通过服务器中转调用阿里云 DashScope，API Key 仅存储在服务器端
/// 支持：预设音色 TTS + 语音克隆
final class CosyVoiceService {
    static let shared = CosyVoiceService()

    private let apiClient = ServerAPIClient.shared

    private init() {}

    // MARK: - TTS 合成

    /// 使用 CosyVoice 将文本转为语音
    /// - Parameters:
    ///   - text: 要合成的文本（单次最多 1000 字符）
    ///   - voiceId: 音色 ID（预设或克隆的 voice_id）
    ///   - rate: 语速（0.5 ~ 2.0）
    /// - Returns: 音频数据（PCM/WAV）
    func synthesize(text: String, voiceId: String, rate: Float = 1.0) async throws -> Data {
        return try await apiClient.requestTTS(text: text, voiceId: voiceId, rate: rate)
    }

    // MARK: - 语音克隆

    /// 克隆声音（上传参考音频）
    /// - Parameters:
    ///   - audioData: 参考音频数据（WAV/MP3，10-30秒）
    ///   - voiceName: 自定义音色名称
    /// - Returns: 克隆后的 voice_id
    func cloneVoice(audioData: Data, voiceName: String) async throws -> String {
        return try await apiClient.requestVoiceClone(audioData: audioData, voiceName: voiceName)
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
    case invalidResponse
    case noAudioData
    case apiError(statusCode: Int, message: String)
    case audioTooShort
    case networkError(Error)

    var errorDescription: String? {
        switch self {
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
