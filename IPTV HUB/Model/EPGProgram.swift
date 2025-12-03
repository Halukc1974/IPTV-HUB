//
//  EPGProgram.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//


import Foundation

// Represents the <programme> tag in XMLTV format
struct EPGProgram: Identifiable, Hashable {
    // We can combine channelID and start time to generate a unique ID
    var id: String {
        return "\(channelID)-\(startDate.timeIntervalSince1970)"
    }
    
    var channelID: String = ""   // 'channel' attribute of <programme>
    var title: String = ""       // <title> tag
    var desc: String = ""        // <desc> tag
    var startDate: Date = Date() // 'start' attribute
    var stopDate: Date = Date()  // 'stop' attribute
    
    // Additional attributes (category, icon, etc.) can be added
}
