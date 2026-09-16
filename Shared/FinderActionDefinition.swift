import Foundation

struct FinderActionDefinition: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case script
    }

    let id: String
    let kind: Kind
    let name: String
    let builtInIdentifier: String?
    let scriptPath: String?

    static let alacritty = FinderActionDefinition(id: "builtin.alacritty", kind: .builtIn, name: "Alacritty", builtInIdentifier: "alacritty", scriptPath: nil)
    static let code = FinderActionDefinition(id: "builtin.code", kind: .builtIn, name: "Code", builtInIdentifier: "code", scriptPath: nil)
    static let supportedApplications = [alacritty, code]

    static func script(path: String) -> FinderActionDefinition {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return FinderActionDefinition(
            id: "script.\(UUID().uuidString)",
            kind: .script,
            name: url.deletingPathExtension().lastPathComponent,
            builtInIdentifier: nil,
            scriptPath: url.path
        )
    }
}

enum FinderActionStore {
    static let actionsKey = "finderActions"
    private static let alacrittyEnabledKey = "alacrittyEnabled"
    private static let codeEnabledKey = "codeEnabled"

    static func load(from defaults: UserDefaults) -> [FinderActionDefinition] {
        if let data = defaults.data(forKey: actionsKey),
           let actions = try? JSONDecoder().decode([FinderActionDefinition].self, from: data) {
            return actions
        }

        return FinderActionDefinition.supportedApplications.filter { action in
            switch action.builtInIdentifier {
            case "alacritty":
                return defaults.object(forKey: alacrittyEnabledKey) as? Bool ?? true
            case "code":
                return defaults.object(forKey: codeEnabledKey) as? Bool ?? true
            default:
                return false
            }
        }
    }

    @discardableResult
    static func save(_ actions: [FinderActionDefinition], to defaults: UserDefaults) -> Bool {
        guard let data = try? JSONEncoder().encode(actions) else { return false }
        defaults.set(data, forKey: actionsKey)
        return true
    }
}
