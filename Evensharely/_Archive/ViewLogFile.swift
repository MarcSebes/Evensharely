//
//  ViewLogFile.swift
//  Evensharely
//
//  Created by Marc Sebes on 4/7/25.
//

import SwiftUI

struct ViewLogFile: View {
    @State private var logText: String = "No log yet."

    var body: some View {
        VStack(spacing: 20) {
            Text("📄 Share Extension Log:")
                .font(.headline)

            ScrollView {
                Text(logText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }

            Button("📥 Load Log File") {
                loadLog()
            }
            .padding()
            Button("Clear Log File") {
               clearLog()
            }
            .padding()
        }
        .padding()
    }

    func loadLog() {
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.marcsebes.evensharely") {
            let fileURL = dir.appendingPathComponent("debug-log.txt")
            if let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
                logText = contents
            } else {
                logText = "❌ Could not read log file."
            }
        }
    }
    func clearLog() {
        if let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.marcsebes.evensharely") {
            let fileURL = dir.appendingPathComponent("debug-log.txt")
            do {
                try "".write(to: fileURL, atomically: true, encoding: .utf8)
                logText = "🧼 Log file cleared."
            } catch {
                logText = "❌ Failed to clear log file: \(error.localizedDescription)"
            }
        } else {
            logText = "❌ Could not find App Group container."
        }
    }
}

