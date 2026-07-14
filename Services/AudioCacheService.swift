// Knowledge/Services/AudioCacheService.swift
import Foundation

/// Edge TTS 音频磁盘缓存服务
/// 缓存 key = hash(text + voice + rate)，value = MP3 文件
/// 最大缓存 500MB，超出时 LRU 淘汰
final class AudioCacheService {
    
    static let shared = AudioCacheService()
    
    private let cacheDir: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024  // 500 MB
    private let fileManager = FileManager.default
    
    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = caches.appendingPathComponent("EdgeTTSAudio", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    // MARK: - Public API
    
    /// 查询缓存，命中时返回音频数据
    func getCachedAudio(text: String, voice: String, rate: Float) -> Data? {
        let key = cacheKey(text: text, voice: voice, rate: rate)
        let fileURL = cacheDir.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        // 更新访问时间（用于 LRU 淘汰）
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        
        return try? Data(contentsOf: fileURL)
    }
    
    /// 写入缓存
    func cacheAudio(_ data: Data, text: String, voice: String, rate: Float) {
        let key = cacheKey(text: text, voice: voice, rate: rate)
        let fileURL = cacheDir.appendingPathComponent(key)
        
        // 已存在则跳过
        guard !fileManager.fileExists(atPath: fileURL.path) else { return }
        
        do {
            try data.write(to: fileURL)
            // 异步检查缓存大小
            Task.detached { [weak self] in
                self?.evictIfNeeded()
            }
        } catch {
            print("⚠️ 音频缓存写入失败: \(error.localizedDescription)")
        }
    }
    
    /// 清除所有缓存
    func clearCache() {
        try? fileManager.removeItem(at: cacheDir)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }
    
    /// 当前缓存大小（字节）
    var cacheSize: Int64 {
        guard let enumerator = fileManager.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
    
    // MARK: - Private
    
    private func cacheKey(text: String, voice: String, rate: Float) -> String {
        let input = "\(voice)|\(rate)|\(text)"
        var hash: UInt64 = 14695981039346656037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16) + ".mp3"
    }
    
    /// LRU 淘汰：删除最旧的文件直到低于阈值
    private func evictIfNeeded() {
        guard cacheSize > maxCacheSize else { return }
        
        guard let enumerator = fileManager.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        // 收集所有文件及其修改时间
        var files: [(url: URL, date: Date, size: Int64)] = []
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let date = values?.contentModificationDate ?? .distantPast
            let size = Int64(values?.fileSize ?? 0)
            files.append((fileURL, date, size))
        }
        
        // 按修改时间升序排列（最旧的在前）
        files.sort { $0.date < $1.date }
        
        // 删除最旧的文件直到低于阈值
        var currentSize = cacheSize
        for file in files {
            guard currentSize > maxCacheSize * 4 / 5 else { break }  // 删到 80% 阈值
            try? fileManager.removeItem(at: file.url)
            currentSize -= file.size
        }
    }
}
