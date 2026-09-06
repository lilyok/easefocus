import Foundation

nonisolated enum L10n {
    static let english = Locale(identifier: "en")
    static let spanish = Locale(identifier: "es")
}

nonisolated struct LocalizedCopy: Sendable, Equatable {
    var resource: LocalizedStringResource
    var english: String

    init(_ english: String) {
        self.english = english
        resource = LocalizedStringResource(stringLiteral: english)
    }

    init(format value: String.LocalizationValue, english: String) {
        resource = LocalizedStringResource(value)
        self.english = english
    }

    func localized(_ locale: Locale = .autoupdatingCurrent) -> String {
        var resource = resource
        resource.locale = locale
        return String(localized: resource)
    }

    func contains(_ other: String) -> Bool {
        english.contains(other)
    }

    var isEmpty: Bool {
        english.isEmpty
    }

    static func == (lhs: LocalizedCopy, rhs: LocalizedCopy) -> Bool {
        lhs.english == rhs.english
    }
}

nonisolated func == (lhs: LocalizedCopy, rhs: String) -> Bool {
    lhs.english == rhs
}

nonisolated func == (lhs: String, rhs: LocalizedCopy) -> Bool {
    lhs == rhs.english
}

nonisolated func == (lhs: String?, rhs: LocalizedCopy) -> Bool {
    guard let lhs else { return false }
    return lhs == rhs.english
}

nonisolated func == (lhs: LocalizedCopy, rhs: String?) -> Bool {
    rhs == lhs
}

nonisolated func == (lhs: LocalizedCopy?, rhs: LocalizedCopy) -> Bool {
    lhs == Optional(rhs)
}

nonisolated func == (lhs: LocalizedCopy, rhs: LocalizedCopy?) -> Bool {
    Optional(lhs) == rhs
}

nonisolated func == (lhs: LocalizedCopy?, rhs: String) -> Bool {
    guard let lhs else { return false }
    return lhs.english == rhs
}

nonisolated func == (lhs: String, rhs: LocalizedCopy?) -> Bool {
    rhs == lhs
}
