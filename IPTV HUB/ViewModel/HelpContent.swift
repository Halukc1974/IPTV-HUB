import Foundation

struct HelpContent {
    struct FAQItem: Identifiable {
        let id = UUID()
        let question: String
        let answers: [String]
    }
    
    let title: String
    let intro: String
    let faqs: [FAQItem]
    let outro: String
    
    static let easyIPTV = HelpContent(
        title: "Easy IPTV Quick Help",
        intro: "Use this FAQ whenever you need a detailed reminder of how each area of the app behaves. Every answer is written as a short checklist so you can follow it step by step.",
        faqs: [
            FAQItem(
                question: "How do I add my very first playlist?",
                answers: [
                    "Open the Playlists tab (labelled \"Playlists\" on iOS and \"lists\" on tvOS) — this is where every playlist is stored.",
                    "Press the Add Playlist button, pick a playlist type (M3U8, Xtream, or Stremio) and give it a friendly name plus an icon so it is easy to spot later.",
                    "Fill in the required URL or credentials for the selected type, keeping an eye on the placeholders for the correct format.",
                    "Tap Save; the playlist is persisted in PlaylistManager and appears in the list ready to be loaded with a single tap."
                ]
            ),
            FAQItem(
                question: "What playlist formats are supported and when should I use each?",
                answers: [
                    "M3U8: classic HTTP playlists that optionally link to an XMLTV/EPG file — ideal when your IPTV provider hands you two URLs.",
                    "Xtream Codes: use this when your provider exposes a portal that needs a base server URL, username, and password.",
                    "Stremio Add-on: perfect for community-made VoD add-ons; just paste the add-on URL and Easy IPTV fetches its catalog.",
                    "Choose the type before entering data so the form shows the exact fields you need; the wrong type will hide required inputs."
                ]
            ),
            FAQItem(
                question: "How do I refresh playlists or schedule automatic updates?",
                answers: [
                    "Manual refresh: open the Playlists tab, tap the circular arrow in the toolbar, and the last loaded playlist is fetched again.",
                    "Automatic refresh: visit Settings → Update Playlists and pick Daily, Every 3 Days, Weekly, or Monthly depending on how often your sources change.",
                    "The selected mode is stored in AppStorage, so you can revert to Manual anytime if you prefer explicit control.",
                    "When the app launches it remembers the last loaded playlist ID; if nothing is loaded yet you can trigger the reload from Settings or Playlists."
                ]
            ),
            FAQItem(
                question: "How do I organize channels with custom categories?",
                answers: [
                    "Open the Categories tab to create, rename, or delete personal folders (ChannelCategory items).",
                    "While watching, press the heart icon in the overlay (tvOS/iOS) to toggle the current channel inside any category without leaving playback.",
                    "Category membership is stored locally using persistent IDs, so reorganizing channels never alters the original playlist data.",
                    "Enable \"Only My Categories\" under Settings → Display Options if you want the Home view to show only your curated folders."
                ]
            ),
            FAQItem(
                question: "How does the Home screen decide which rows appear?",
                answers: [
                    "The sticky header lets you filter by playlist and run a global search; both affect every row instantly.",
                    "Recent Watches shows the last 10 channels you opened; disable the toggle in Settings if you want a cleaner dashboard.",
                    "Popular Channels pulls the top entries (or filtered results when searching) so you can quickly jump back into trending items.",
                    "Additional rows are generated from your categories and the playlist’s original groups unless \"Only My Categories\" is enabled."
                ]
            ),
            FAQItem(
                question: "What is the fastest way to change channels while streaming?",
                answers: [
                    "tvOS: swipe left or right on the Siri Remote while the overlay is hidden to zap instantly through the TabView zapping layer.",
                    "iOS: swipe horizontally on the player surface; each swipe updates the TabView index and loads the channel after a short debounce.",
                    "Tap or press Play/Pause to bring up the overlay, then hit the list icon to open the searchable Channel List and jump directly to any entry.",
                    "Remember that the overlay also exposes mute, aspect ratio, favorite/category assignment, and the new Quick Help button for rapid tips."
                ]
            ),
            FAQItem(
                question: "How do I browse the full TV Guide (EPG) viewer?",
                answers: [
                    "When adding or editing an M3U playlist, enter the XMLTV/EPG URL so Easy IPTV can download program data in the background.",
                    "After parsing, the Guide tab displays channels with their timelines; scroll vertically to change channels and horizontally to move along the schedule.",
                    "Large EPG files may take a moment to parse; the spinner disappears once the cache is ready, and subsequent visits are instant.",
                    "If a playlist lacks EPG identifiers, the Guide will remain empty for those channels — this is expected behavior."
                ]
            ),
            FAQItem(
                question: "Which player engine should I choose and how do the advanced toggles help streaming performance?",
                answers: [
                    "Pick KSPlayer (Metal) for the best balance between hardware decoding and smooth UI integration.",
                    "VLCKit is great when you need broad codec support; AVKit keeps everything native, and MPV is for power users who can tolerate experimental behavior.",
                    "Use the Player Settings section to toggle hardware decode, caching, adaptive frame rate, asynchronous decompression, and live-pause depending on your provider’s recommendations.",
                    "If a stream stutters, try raising the buffer duration slider (1–10 seconds) or switching to another player engine before troubleshooting your playlist."
                ]
            ),
            FAQItem(
                question: "How do I manage audio languages, subtitles, and OpenSubtitles credentials?",
                answers: [
                    "Open Settings → Player Settings and navigate to the dedicated Audio Language and Subtitle Language pickers; selections are saved via AppStorage instantly.",
                    "Adjust the Subtitle Font Size stepper if you use KSPlayer; other engines ignore the size warning by design.",
                    "Scroll further down to the OpenSubtitles section and enter your username (not email) plus password to enable automatic subtitle lookup.",
                    "Return to playback and tap the captions button in your player of choice to request subs once the credentials are stored."
                ]
            ),
            FAQItem(
                question: "Can I connect Emby or Plex for on-demand libraries?",
                answers: [
                    "Yes. Open Settings → External Servers and tap \"Emby & Plex Connection\" to enter each server’s base URL and personal token/API key.",
                    "Tokens never leave your device; they are stored in AppStorage and only used when you tap \"Test Connection & Save\" to validate access.",
                    "Keep the hint examples (IP with port for Emby, Plex Direct URL for Plex) as a template to avoid typos.",
                    "You can update or clear credentials any time without affecting live playlists or categories."
                ]
            ),
            FAQItem(
                question: "How do I capture, view, or clean up recently watched channels?",
                answers: [
                    "Easy IPTV stores a rolling list of channel IDs in UserDefaults each time you open a stream.",
                    "The Home view reads those IDs, matches them against currently loaded channels (using stable identifiers when needed), and shows them under Recent Watches.",
                    "Disable the \"Recent Watches\" toggle in Settings → Display Options if you prefer not to maintain that history.",
                    "Re-enabling the toggle immediately restores the stored list; clearing UserDefaults (via system settings) resets it completely."
                ]
            ),
            FAQItem(
                question: "How can I troubleshoot buffering or playback failures?",
                answers: [
                    "First, verify the playlist URL is reachable in a browser; many failures stem from expired credentials rather than the app itself.",
                    "Switch player engines (KSPlayer → VLCKit → AVKit) — some providers deliver streams optimized for a specific decoder.",
                    "Raise the buffer duration and temporarily disable adaptive frame rate or caching to see if the provider is already managing those settings.",
                    "Use the Quick Help button (?) inside the overlay to revisit these steps on-device without leaving playback."
                ]
            ),
            FAQItem(
                question: "Where can I find legal, privacy, and support information?",
                answers: [
                    "Go to Settings → Support and pick \"Quick Help\" for this FAQ or \"Terms & Privacy\" for the full TermsContent copy.",
                    "The same Quick Help view is accessible from the player overlay via the question-mark icon; the sheet can be dismissed with the Close button or the remote’s back gesture.",
                    "TermsContent is bundled directly with the app, so no network connection is needed to review policies.",
                    "Contact details sit at the bottom of the Terms page; reach out through the listed email if you need further assistance."
                ]
            )
        ],
        outro: "Need to double-check anything mid-stream? Tap or click the ? icon in the player overlay to open this FAQ without leaving playback."
    )
}
