import Foundation

struct KnownService: Identifiable {
    let id = UUID()
    let name: String
    let defaultPrice: Double
    let currency: String
    let billingCycle: BillingCycle
    let category: String
    let domain: String

    var logoUrl: String {
        "https://img.logo.dev/\(domain)?token=pk_LURXB378TgS-zdvustF4Bg&size=128"
    }

    var url: String {
        "https://\(domain)"
    }
}

enum KnownServices {
    static let all: [KnownService] = [
        // Streaming
        KnownService(name: "Netflix", defaultPrice: 15.49, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "netflix.com"),
        KnownService(name: "Disney+", defaultPrice: 13.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "disneyplus.com"),
        KnownService(name: "Hulu", defaultPrice: 17.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "hulu.com"),
        KnownService(name: "HBO Max", defaultPrice: 15.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "max.com"),
        KnownService(name: "Amazon Prime Video", defaultPrice: 14.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "primevideo.com"),
        KnownService(name: "Apple TV+", defaultPrice: 9.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "tv.apple.com"),
        KnownService(name: "Peacock", defaultPrice: 7.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "peacocktv.com"),
        KnownService(name: "Paramount+", defaultPrice: 11.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "paramountplus.com"),
        KnownService(name: "Crunchyroll", defaultPrice: 7.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "crunchyroll.com"),
        KnownService(name: "YouTube Premium", defaultPrice: 13.99, currency: "USD", billingCycle: .monthly, category: "Streaming", domain: "youtube.com"),

        // Music
        KnownService(name: "Spotify", defaultPrice: 11.99, currency: "USD", billingCycle: .monthly, category: "Music", domain: "spotify.com"),
        KnownService(name: "Apple Music", defaultPrice: 10.99, currency: "USD", billingCycle: .monthly, category: "Music", domain: "music.apple.com"),
        KnownService(name: "Tidal", defaultPrice: 10.99, currency: "USD", billingCycle: .monthly, category: "Music", domain: "tidal.com"),
        KnownService(name: "Amazon Music", defaultPrice: 9.99, currency: "USD", billingCycle: .monthly, category: "Music", domain: "music.amazon.com"),
        KnownService(name: "Deezer", defaultPrice: 10.99, currency: "USD", billingCycle: .monthly, category: "Music", domain: "deezer.com"),
        KnownService(name: "SoundCloud Go+", defaultPrice: 9.99, currency: "USD", billingCycle: .monthly, category: "Music", domain: "soundcloud.com"),

        // Software
        KnownService(name: "Microsoft 365", defaultPrice: 99.99, currency: "USD", billingCycle: .yearly, category: "Software", domain: "microsoft.com"),
        KnownService(name: "Adobe Creative Cloud", defaultPrice: 59.99, currency: "USD", billingCycle: .monthly, category: "Software", domain: "adobe.com"),
        KnownService(name: "Notion", defaultPrice: 10.00, currency: "USD", billingCycle: .monthly, category: "Software", domain: "notion.so"),
        KnownService(name: "1Password", defaultPrice: 35.88, currency: "USD", billingCycle: .yearly, category: "Software", domain: "1password.com"),
        KnownService(name: "Bitwarden", defaultPrice: 10.00, currency: "USD", billingCycle: .yearly, category: "Software", domain: "bitwarden.com"),
        KnownService(name: "Todoist", defaultPrice: 48.00, currency: "USD", billingCycle: .yearly, category: "Software", domain: "todoist.com"),
        KnownService(name: "Slack", defaultPrice: 8.75, currency: "USD", billingCycle: .monthly, category: "Software", domain: "slack.com"),
        KnownService(name: "Zoom", defaultPrice: 13.33, currency: "USD", billingCycle: .monthly, category: "Software", domain: "zoom.us"),
        KnownService(name: "GitHub Pro", defaultPrice: 4.00, currency: "USD", billingCycle: .monthly, category: "Software", domain: "github.com"),
        KnownService(name: "JetBrains All Products", defaultPrice: 289.00, currency: "USD", billingCycle: .yearly, category: "Software", domain: "jetbrains.com"),
        KnownService(name: "Figma", defaultPrice: 15.00, currency: "USD", billingCycle: .monthly, category: "Software", domain: "figma.com"),
        KnownService(name: "Canva Pro", defaultPrice: 12.99, currency: "USD", billingCycle: .monthly, category: "Software", domain: "canva.com"),
        KnownService(name: "Grammarly", defaultPrice: 12.00, currency: "USD", billingCycle: .monthly, category: "Software", domain: "grammarly.com"),

        // Gaming
        KnownService(name: "Xbox Game Pass", defaultPrice: 16.99, currency: "USD", billingCycle: .monthly, category: "Gaming", domain: "xbox.com"),
        KnownService(name: "PlayStation Plus", defaultPrice: 59.99, currency: "USD", billingCycle: .yearly, category: "Gaming", domain: "playstation.com"),
        KnownService(name: "Nintendo Switch Online", defaultPrice: 19.99, currency: "USD", billingCycle: .yearly, category: "Gaming", domain: "nintendo.com"),
        KnownService(name: "EA Play", defaultPrice: 29.99, currency: "USD", billingCycle: .yearly, category: "Gaming", domain: "ea.com"),

        // Cloud Storage
        KnownService(name: "iCloud+", defaultPrice: 2.99, currency: "USD", billingCycle: .monthly, category: "Cloud Storage", domain: "icloud.com"),
        KnownService(name: "Google One", defaultPrice: 2.99, currency: "USD", billingCycle: .monthly, category: "Cloud Storage", domain: "one.google.com"),
        KnownService(name: "Dropbox Plus", defaultPrice: 11.99, currency: "USD", billingCycle: .monthly, category: "Cloud Storage", domain: "dropbox.com"),

        // Fitness
        KnownService(name: "Peloton", defaultPrice: 44.00, currency: "USD", billingCycle: .monthly, category: "Fitness", domain: "onepeloton.com"),
        KnownService(name: "Strava", defaultPrice: 79.99, currency: "USD", billingCycle: .yearly, category: "Fitness", domain: "strava.com"),
        KnownService(name: "MyFitnessPal", defaultPrice: 79.99, currency: "USD", billingCycle: .yearly, category: "Fitness", domain: "myfitnesspal.com"),
        KnownService(name: "Headspace", defaultPrice: 69.99, currency: "USD", billingCycle: .yearly, category: "Fitness", domain: "headspace.com"),
        KnownService(name: "Calm", defaultPrice: 69.99, currency: "USD", billingCycle: .yearly, category: "Fitness", domain: "calm.com"),

        // News
        KnownService(name: "The New York Times", defaultPrice: 17.00, currency: "USD", billingCycle: .monthly, category: "News", domain: "nytimes.com"),
        KnownService(name: "The Washington Post", defaultPrice: 10.00, currency: "USD", billingCycle: .monthly, category: "News", domain: "washingtonpost.com"),
        KnownService(name: "The Wall Street Journal", defaultPrice: 38.99, currency: "USD", billingCycle: .monthly, category: "News", domain: "wsj.com"),
        KnownService(name: "The Athletic", defaultPrice: 9.99, currency: "USD", billingCycle: .monthly, category: "News", domain: "theathletic.com"),
        KnownService(name: "Medium", defaultPrice: 5.00, currency: "USD", billingCycle: .monthly, category: "News", domain: "medium.com"),
        KnownService(name: "Apple News+", defaultPrice: 12.99, currency: "USD", billingCycle: .monthly, category: "News", domain: "apple.com"),

        // Other
        KnownService(name: "Amazon Prime", defaultPrice: 14.99, currency: "USD", billingCycle: .monthly, category: "Other", domain: "amazon.com"),
        KnownService(name: "ChatGPT Plus", defaultPrice: 20.00, currency: "USD", billingCycle: .monthly, category: "Other", domain: "openai.com"),
        KnownService(name: "Claude Pro", defaultPrice: 20.00, currency: "USD", billingCycle: .monthly, category: "Other", domain: "anthropic.com"),
        KnownService(name: "Duolingo Plus", defaultPrice: 6.99, currency: "USD", billingCycle: .monthly, category: "Other", domain: "duolingo.com"),
    ]

    static func search(_ query: String) -> [KnownService] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()
        return all.filter { $0.name.lowercased().contains(lowercased) }
    }
}
