import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        guard let url = Self.configValue(
            environmentKey: "SUPABASE_URL",
            infoPlistKey: "SUPABASE_URL"
        ) else {
            fatalError(Self.missingConfigMessage(for: "SUPABASE_URL"))
        }
        guard let key = Self.configValue(
            environmentKey: "SUPABASE_ANON_KEY",
            infoPlistKey: "SUPABASE_ANON_KEY"
        ) else {
            fatalError(Self.missingConfigMessage(for: "SUPABASE_ANON_KEY"))
        }

        guard let supabaseURL = URL(string: url), supabaseURL.host != nil else {
            fatalError(Self.invalidURLMessage(url))
        }

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key
        )
    }

    private static func configValue(environmentKey: String, infoPlistKey: String) -> String? {
        if let value = normalizedValue(ProcessInfo.processInfo.environment[environmentKey]) {
            return value
        }

        return normalizedValue(Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String)
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    private static func missingConfigMessage(for key: String) -> String {
        #if DEBUG
        return "Missing \(key). Debug builds require explicit Supabase credentials. Set Xcode scheme environment variables or create SubTrkr/Secrets.xcconfig from SubTrkr/Secrets.example.xcconfig."
        #else
        return "Missing \(key) — set in environment variables or Info.plist"
        #endif
    }

    private static func invalidURLMessage(_ value: String) -> String {
        #if DEBUG
        return "Invalid SUPABASE_URL: \(value). If you set it in an .xcconfig file, do not use a raw https:// value because xcconfig treats // as a comment."
        #else
        return "Invalid SUPABASE_URL: \(value)"
        #endif
    }
}
