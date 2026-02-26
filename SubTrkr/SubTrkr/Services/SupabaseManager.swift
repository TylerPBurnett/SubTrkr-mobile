import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        guard let url = ProcessInfo.processInfo.environment["SUPABASE_URL"]
                ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            fatalError("Missing SUPABASE_URL — set in environment variables or Info.plist")
        }
        guard let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
                ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else {
            fatalError("Missing SUPABASE_ANON_KEY — set in environment variables or Info.plist")
        }

        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }
}
