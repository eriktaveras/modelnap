import Foundation

/// Textos traducibles. La clave es el propio texto en español (idioma base), así
/// el código se lee igual que la interfaz; las traducciones viven en
/// Resources/<idioma>.lproj/Localizable.strings y lo que falte sale en español.
func tr(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

func tr(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

/// Idioma elegido en Ajustes. «Automático» sigue al sistema; los otros fijan
/// `AppleLanguages` solo para esta app, que Foundation lee al arrancar.
enum Language: String, CaseIterable {
    case auto, es, en

    var label: String {
        switch self {
        case .auto: return tr("Auto")
        case .es: return "ES"
        case .en: return "EN"
        }
    }

    static var current: Language {
        guard let langs = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLanguages"] as? [String],
              let first = langs.first else { return .auto }
        return first.hasPrefix("en") ? .en : first.hasPrefix("es") ? .es : .auto
    }

    func apply() {
        if self == .auto {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}
