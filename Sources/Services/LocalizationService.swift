import Foundation

/// Localization service to detect system language and provide translations
final class LocalizationService {
    static let shared = LocalizationService()
    
    /// Current locale language code (e.g., "zh-Hans", "en")
    var currentLanguageCode: String {
        // Use preferred languages to get the user's primary language
        let preferredLanguages = Locale.preferredLanguages
        if let firstLanguage = preferredLanguages.first {
            // Extract language code from something like "zh-Hans" or "zh-CN"
            let languageCode = String(firstLanguage.prefix(2))
            return languageCode
        }
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// Check if current system language is Simplified Chinese
    var isSimplifiedChinese: Bool {
        // Check preferred languages first
        let preferredLanguages = Locale.preferredLanguages
        
        for language in preferredLanguages {
            // Check for Chinese variants
            if language.hasPrefix("zh") {
                // zh-Hans, zh-CN, zh-Hans-CN, zh-SG, etc. are Simplified Chinese
                // zh-Hant, zh-TW, zh-HK are Traditional Chinese
                if language.contains("Hans") || language.contains("CN") || language.contains("SG") {
                    return true
                }
                // If just "zh" without script, check the identifier
                if language == "zh" {
                    // Check if current locale identifier suggests Simplified
                    let identifier = Locale.current.identifier
                    if identifier.contains("Hans") || identifier.contains("CN") || identifier.contains("SG") {
                        return true
                    }
                    // Default to Simplified for zh without qualifier on macOS in China
                    return true
                }
                // zh-Hant, zh-TW, zh-HK are Traditional Chinese
                if language.contains("Hant") || language.contains("TW") || language.contains("HK") {
                    return false
                }
                // Default to Simplified
                return true
            }
        }
        
        return false
    }
    
    private init() {}
}
