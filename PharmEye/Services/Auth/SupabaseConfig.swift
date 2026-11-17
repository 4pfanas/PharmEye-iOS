import Foundation

/// Your Supabase project, read at runtime from `Supabase.plist` in the app bundle.
/// That file is git-ignored so real values never end up in source control: copy
/// `Config/Supabase.example.plist` to `PharmEye/Supabase.plist` and fill in
/// `SupabaseURL` and `SupabaseAnonKey` (Dashboard → Project Settings → API Keys —
/// the publishable `sb_publishable_…` key or the legacy anon key, never the
/// service-role/secret key).
///
/// Dashboard setup (Authentication → Providers / URL Configuration):
/// - Email: enabled. Turn "Confirm email" on or off as you like; the app handles both.
/// - Apple: enabled, with this app's bundle ID under "Client IDs".
/// - Google: enabled, with a Web client ID + secret from Google Cloud Console.
/// - Redirect URLs: add `pharmeye://auth-callback` (used by Google sign-in).
enum SupabaseConfig {
    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return dict
    }()

    static var url: String { values["SupabaseURL"] ?? "" }
    static var anonKey: String { values["SupabaseAnonKey"] ?? "" }

    static let redirectScheme = "pharmeye"
    static let redirectURL = "pharmeye://auth-callback"

    /// False until a real `Supabase.plist` is in place, so the sign-in screen can say so
    /// instead of failing with a network error.
    static var isConfigured: Bool {
        url.hasPrefix("https://") && !url.contains("YOUR-PROJECT")
            && !anonKey.isEmpty && !anonKey.contains("YOUR-SUPABASE")
    }
}
