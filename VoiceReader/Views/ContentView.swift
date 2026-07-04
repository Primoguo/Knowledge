// VoiceReader/Views/ContentView.swift
// 占位视图 — Task 8 会替换
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Text("VoiceReader")
                .font(.largeTitle)
                .navigationTitle("有声阅读器")
        }
    }
}

#Preview {
    ContentView()
}
