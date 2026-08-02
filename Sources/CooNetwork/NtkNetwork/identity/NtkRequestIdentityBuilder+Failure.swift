extension NtkRequestIdentityBuilder {

    enum Section: String, Sendable {
        case headers
        case parameters
        case identityComponents
    }

    enum Failure: Error, Sendable, Equatable {
        case unsupportedValue(path: String, type: String)
        case nonFiniteValue(path: String, type: String)
        case normalizationFailed(section: Section, errorType: String)
        case invalidHeaderName(String)
        case duplicateNormalizedHeader(String)
        case projectionCollision(section: Section, key: String)

        var diagnosticDescription: String {
            switch self {
            case .unsupportedValue(let path, let type):
                return "unsupported value at \(path) (type: \(type))"
            case .nonFiniteValue(let path, let type):
                return "non-finite value at \(path) (type: \(type))"
            case .normalizationFailed(let section, let errorType):
                return "normalization failed in \(section.rawValue) (error type: \(errorType))"
            case .invalidHeaderName(let name):
                return "invalid header name at headers.\(name)"
            case .duplicateNormalizedHeader(let name):
                return "duplicate normalized header at headers.\(name)"
            case .projectionCollision(let section, let key):
                return "projection collision in \(section.rawValue).\(key)"
            }
        }
    }
}
