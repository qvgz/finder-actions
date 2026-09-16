import Foundation

struct FinderActionDefinition: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let summaryZH: String
    let summaryEN: String
    let scriptFileName: String
}

enum FinderActionStore {
    static let actionsKey = "localizedScriptActions"

    static func load(from defaults: UserDefaults) -> [FinderActionDefinition] {
        guard let data = defaults.data(forKey: actionsKey),
              let actions = try? JSONDecoder().decode([FinderActionDefinition].self, from: data)
        else { return [] }
        return actions
    }

    @discardableResult
    static func save(_ actions: [FinderActionDefinition], to defaults: UserDefaults) -> Bool {
        guard let data = try? JSONEncoder().encode(actions) else { return false }
        defaults.set(data, forKey: actionsKey)
        return true
    }
}
