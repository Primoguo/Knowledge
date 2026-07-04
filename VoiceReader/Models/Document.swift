// VoiceReader/Models/Document.swift
// 占位模型 — Task 2 会完善
import Foundation
import SwiftData

@Model
final class Document {
    var id: UUID
    var title: String
    var fileName: String
    var fileType: String
    var extractedText: String
    var currentPosition: Int
    var totalLength: Int
    var lastOpenedDate: Date
    var createdAt: Date
    var isFavorite: Bool
    var progress: Double

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        fileType: String,
        extractedText: String = "",
        currentPosition: Int = 0,
        totalLength: Int = 0,
        lastOpenedDate: Date = Date(),
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        progress: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.fileType = fileType
        self.extractedText = extractedText
        self.currentPosition = currentPosition
        self.totalLength = totalLength
        self.lastOpenedDate = lastOpenedDate
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.progress = progress
    }
}
