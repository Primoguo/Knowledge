// Knowledge/Services/SpeechRecognitionService.swift
import Speech
import AVFoundation

/// STT 服务 — 双层策略
/// 免费用户：Apple Speech 框架（本地、离线、无时间戳）
/// Premium 用户：服务器中转阿里云百炼（云端、高准确率、字级时间戳）
final class SpeechRecognitionService {

    static let shared = SpeechRecognitionService()
    private init() {}

    // MARK: - 转写结果

    struct TranscriptionResult {
        var text: String
        var sentences: [VnoteSentence]  // Premium 时有时间戳
        var isPremium: Bool
    }

    // MARK: - 转写入口

    /// 对录音文件进行语音转写
    /// - Parameters:
    ///   - audioURL: 录音文件本地路径
    ///   - isPremium: 是否使用 Premium 云端识别
    func transcribe(audioURL: URL, isPremium: Bool) async throws -> TranscriptionResult {
        if isPremium {
            return try await transcribeWithServer(audioURL: audioURL)
        } else {
            return try await transcribeWithApple(audioURL: audioURL)
        }
    }

    // MARK: - 免费：Apple Speech 框架

    private func transcribeWithApple(audioURL: URL) async throws -> TranscriptionResult {
        // 请求权限
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw STTError.speechPermissionDenied
        }

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        guard let recognizer = recognizer, recognizer.isAvailable else {
            // 回退到英文
            let enRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            guard let enRecognizer = enRecognizer, enRecognizer.isAvailable else {
                throw STTError.recognizerUnavailable
            }
            return try await performAppleRecognition(recognizer: enRecognizer, audioURL: audioURL)
        }

        return try await performAppleRecognition(recognizer: recognizer, audioURL: audioURL)
    }

    private func performAppleRecognition(recognizer: SFSpeechRecognizer, audioURL: URL) async throws -> TranscriptionResult {
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false  // 允许离线

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    continuation.resume(returning: TranscriptionResult(
                        text: text,
                        sentences: [],  // Apple Speech 不提供时间戳
                        isPremium: false
                    ))
                }
            }
        }
    }

    // MARK: - Premium：服务器中转阿里云百炼

    private func transcribeWithServer(audioURL: URL) async throws -> TranscriptionResult {
        let audioData = try Data(contentsOf: audioURL)
        let fileName = audioURL.lastPathComponent

        // 构建 multipart 请求
        let url = URL(string: "\(ServerAPIClient.baseURL)/stt")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw STTError.serverError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw STTError.invalidResponse
        }

        let text = json["text"] as? String ?? ""

        // 解析 sentences + words
        var sentences: [VnoteSentence] = []
        if let rawSentences = json["sentences"] as? [[String: Any]] {
            for s in rawSentences {
                let sText = s["text"] as? String ?? ""
                let beginTime = s["beginTime"] as? Int ?? 0
                let endTime = s["endTime"] as? Int ?? 0

                var words: [VnoteWord] = []
                if let rawWords = s["words"] as? [[String: Any]] {
                    for w in rawWords {
                        words.append(VnoteWord(
                            text: w["text"] as? String ?? "",
                            beginTime: w["beginTime"] as? Int ?? 0,
                            endTime: w["endTime"] as? Int ?? 0,
                            punctuation: w["punctuation"] as? String ?? ""
                        ))
                    }
                }

                sentences.append(VnoteSentence(
                    text: sText,
                    beginTime: beginTime,
                    endTime: endTime,
                    words: words
                ))
            }
        }

        print("[STT] Server: \(text.count) chars, \(sentences.count) sentences")

        return TranscriptionResult(
            text: text,
            sentences: sentences,
            isPremium: true
        )
    }
}

// MARK: - Errors

enum STTError: LocalizedError {
    case speechPermissionDenied
    case recognizerUnavailable
    case serverError
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "需要语音识别权限，请在设置中开启"
        case .recognizerUnavailable:
            return "语音识别服务不可用，请检查网络连接"
        case .serverError:
            return "云端识别服务异常，请稍后重试"
        case .invalidResponse:
            return "识别结果解析失败"
        }
    }
}
