//
//  TermsContent.swift
//  IPTV HUB
//
//  Created by Haluk CELEBI on 3.12.2025.
//


//
//  TermsContent 2.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 2.12.2025.
//


import Foundation

struct TermsContent {
    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let paragraphs: [String]
        let bullets: [String]
        let linkTitle: String?
        let linkURL: URL?
        
        init(title: String,
             paragraphs: [String] = [],
             bullets: [String] = [],
             linkTitle: String? = nil,
             linkURL: URL? = nil) {
            self.title = title
            self.paragraphs = paragraphs
            self.bullets = bullets
            self.linkTitle = linkTitle
            self.linkURL = linkURL
        }
    }
    
    let headerTitle: String
    let updatedText: String
    let sections: [Section]
    let contactDescription: String
    let contactEmailLine: String
    let footerLine: String
    
    static let easyIPTV = TermsContent(
        headerTitle: "TERMS AND CONDITIONS AND PRIVACY POLICY",
        updatedText: "Last Updated: December 1, 2025",
        sections: [
            Section(
                title: "1. INTRODUCTION",
                paragraphs: [
                    "Welcome to [Your App Name] (\"the App\"). By downloading, installing, or using the App, you agree to be bound by these Terms and Conditions and Privacy Policy (\"Agreement\"). This App is developed and operated by [Your Name or Company Name] (\"Developer\")."
                ]
            ),
            Section(
                title: "2. IMPORTANT DISCLAIMER: NO CONTENT PROVIDED",
                paragraphs: ["PLEASE READ CAREFULLY:"],
                bullets: [
                    "The App is strictly a media player and playlist management tool.",
                    "The App DOES NOT provide, include, or distribute any media content, playlists, channels, video streams, or subscriptions.",
                    "The App is sold as a software tool only. You, the User, are solely responsible for adding and configuring your own content (e.g., m3u playlists).",
                    "The Developer has no affiliation with any third-party content providers."
                ]
            ),
            Section(
                title: "3. COPYRIGHT AND INTELLECTUAL PROPERTY",
                bullets: [
                    "The App Code: The Developer retains all ownership rights, including intellectual property and copyrights, to the App's source code, design, and interface.",
                    "User Content: The Developer claims no ownership over the content or playlists imported by the User. The User bears full responsibility for the content they access.",
                    "Copyright Infringement: We have a zero-tolerance policy regarding copyright infringement. The App must not be used to stream illegal or pirated content. If you do not have the legal right to access a stream, you must not use this App to play it."
                ]
            ),
            Section(
                title: "4. PRIVACY POLICY (NO DATA COLLECTION)",
                paragraphs: ["We respect your privacy. Our business model is selling a software tool, not selling user data."],
                bullets: [
                    "No Personal Data Collection: We do not collect, store, process, or share any personal information (such as names, emails, IP addresses, or location data).",
                    "No Tracking: We do not use third-party tracking cookies or analytics services to monitor your usage habits.",
                    "Local Storage: Any data you enter into the App (such as playlist URLs or channel favorites) is stored locally on your Apple device and is not transmitted to the Developer's servers.",
                    "Third-Party Services: If you use the App to connect to third-party servers (e.g., your IPTV provider), your interaction is subject to their privacy policies. We have no control over third-party servers."
                ]
            ),
            Section(
                title: "5. APPLE STANDARD EULA",
                paragraphs: [
                    "This App is subject to the Apple Licensed Application End User License Agreement (Standard EULA). By using this App, you agree to the terms set forth by Apple. In the event of any conflict between this Agreement and the Apple Standard EULA, the Apple Standard EULA shall prevail regarding platform usage, while this Agreement governs specific App functionality and content disclaimers."
                ],
                linkTitle: "View Apple Standard EULA",
                linkURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
            ),
            Section(
                title: "6. LIMITATION OF LIABILITY",
                paragraphs: [
                    "To the maximum extent permitted by law, the Developer is not liable for any direct, indirect, incidental, or consequential damages arising from your use or inability to use the App, or for any content you access through the App. The App is provided \"As Is\" without warranties of any kind."
                ]
            ),
            Section(
                title: "7. GOVERNING LAW",
                paragraphs: [
                    "This Agreement is governed by the laws of the Republic of Türkiye. Any legal disputes shall be subject to the exclusive jurisdiction of the courts located in Ankara, Türkiye."
                ]
            )
        ],
        contactDescription: "If you have any questions regarding this Agreement, please contact us at:",
        contactEmailLine: "Email: [Your Support Email Address]",
        footerLine: "© 2025 [Your Name or Company Name]. All rights reserved."
    )
}
