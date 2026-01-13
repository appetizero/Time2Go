import SwiftUI
import Combine

final class LocalizationManager: ObservableObject {

    @AppStorage("appLanguage") var language: String = "en" {
        didSet {
            objectWillChange.send()
        }
    }

    var locale: Locale {
        Locale(identifier: language)
    }

    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    func t(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
