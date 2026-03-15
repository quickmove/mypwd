import Foundation

struct PasswordItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var url: String
    var username: String
    var password: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        url: String = "",
        username: String = "",
        password: String = "",
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.username = username
        self.password = password
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        if let urlHost = URL(string: url)?.host {
            return urlHost
        }
        return url.isEmpty ? "Unnamed" : url
    }
}

struct PasswordStore: Codable {
    var items: [PasswordItem]
    var lastUpdated: Date

    init(items: [PasswordItem] = [], lastUpdated: Date = Date()) {
        self.items = items
        self.lastUpdated = lastUpdated
    }
}
