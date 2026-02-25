import Foundation
import Supabase

@Observable
final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        // These would normally come from a config file / environment
        // For development, use placeholder values that will be replaced
        let url = ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? "https://bpgsfyallqqvvtjorybl.supabase.co"
        let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
            ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwZ3NmeWFsbHFxdnZ0am9yeWJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMjM4OTEsImV4cCI6MjA4NDY5OTg5MX0.sj5SH8t80RFRF2HQuCG9dxFgJS5cylUjirbvF57g4w4"

        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key
        )
    }
}
