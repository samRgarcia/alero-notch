import Foundation

/// Idioma de la interfaz: español si el sistema está en español; inglés en cualquier otro caso.
/// Interface language: Spanish when the system is in Spanish; English otherwise.
enum Lang {
    static let isSpanish: Bool = {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("es")
    }()
}

/// Devuelve el texto en el idioma del sistema. / Returns the text in the system language.
func tr(_ es: String, _ en: String) -> String {
    Lang.isSpanish ? es : en
}
