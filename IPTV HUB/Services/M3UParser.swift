import Foundation

enum M3UParserError: Error {
    case invalidData(String)
    case networkError(Error)
}

class M3UParser {
    
    private let networkManager = NetworkManager.shared
    
    func parse(url: URL) async throws -> [Channel] {
        
        // 1. Network Call
        let data: Data
        do {
            data = try await networkManager.fetchData(from: url)
        } catch {
            print("M3UParser NETWORK ERROR DETAIL: \(error.localizedDescription)")
            throw M3UParserError.networkError(error)
        }
        
        // 2. Move CPU-heavy workload to background
        return try await Task.detached(priority: .userInitiated) {
            var reader = LineReader(data: data)
            var channels = [Channel]()
            var pendingExtInf: String?
            var sawHeader = false
            var headerInvalid = false
            
            while let rawLine = reader.nextLine() {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if !sawHeader {
                    sawHeader = true
                    if line.uppercased() != "#EXTM3U" {
                        headerInvalid = true
                        break
                    }
                    continue
                }
                
                if line.isEmpty { continue }
                if line.hasPrefix("#") {
                    if line.uppercased().hasPrefix("#EXTINF:") {
                        pendingExtInf = line
                    }
                    continue
                }
                
                guard let extInfLine = pendingExtInf else { continue }
                pendingExtInf = nil
                if let channel = Channel(extinfLine: extInfLine, urlLine: line) {
                    channels.append(channel)
                }
            }
            
            if !sawHeader || headerInvalid {
                throw M3UParserError.invalidData("A valid #EXTM3U header was not found.")
            }
            
            print("M3UParser: Successfully parsed \(channels.count) channels.")
            return channels
            
        }.value
    }
}

// MARK: - Streaming Line Reader
private struct LineReader {
    private let data: Data
    private var currentIndex: Data.Index
    private let newline: UInt8 = 0x0A // \n
    init(data: Data) {
        self.data = data
        self.currentIndex = data.startIndex
    }
    
    mutating func nextLine() -> String? {
        guard currentIndex < data.endIndex else { return nil }
        let remainingRange = currentIndex..<data.endIndex
        if let newlineIndex = data[remainingRange].firstIndex(of: newline) {
            let lineData = data[currentIndex..<newlineIndex]
            currentIndex = data.index(after: newlineIndex)
            return lineString(from: lineData)
        } else {
            let lineData = data[currentIndex..<data.endIndex]
            currentIndex = data.endIndex
            return lineString(from: lineData)
        }
    }
    
    private func lineString(from slice: Data.SubSequence) -> String? {
        var trimmed = slice
        if let last = trimmed.last, last == 0x0D { // Remove \r for Windows line endings
            trimmed = trimmed.dropLast()
        }
        return String(data: Data(trimmed), encoding: .utf8)
    }
}
