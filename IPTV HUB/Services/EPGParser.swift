//
//  EPGParser.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//


import Foundation

final class EPGParser {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    func parse(data: Data) -> [EPGProgram] {
        let delegate = ParserDelegate(dateFormatter: dateFormatter)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.programs
    }
    
    func parseAsync(data: Data) async -> [EPGProgram] {
        await Task.detached(priority: .utility) { [dateFormatter] in
            let delegate = ParserDelegate(dateFormatter: dateFormatter)
            let parser = XMLParser(data: data)
            parser.delegate = delegate
            parser.parse()
            return delegate.programs
        }.value
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    private let dateFormatter: DateFormatter
    private(set) var programs: [EPGProgram] = []
    private var currentProgram: EPGProgram?
    private var currentElement: String = ""
    private var currentAttributes: [String: String] = [:]
    
    init(dateFormatter: DateFormatter) {
        self.dateFormatter = dateFormatter
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "programme" {
            currentAttributes = attributeDict
            currentProgram = EPGProgram()
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let data = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !data.isEmpty else { return }
        switch currentElement {
        case "title":
            currentProgram?.title += data
        case "desc":
            currentProgram?.desc += data
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "programme" {
            if var program = currentProgram {
                if let channel = currentAttributes["channel"] {
                    program.channelID = channel
                }
                if let startString = currentAttributes["start"], let date = dateFormatter.date(from: startString) {
                    program.startDate = date
                }
                if let stopString = currentAttributes["stop"], let date = dateFormatter.date(from: stopString) {
                    program.stopDate = date
                }
                programs.append(program)
                currentProgram = nil
            }
        }
        currentElement = ""
    }
}
