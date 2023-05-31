import Foundation

final class UserHolder {
    private(set) var user: User

    init(user: User) {
        self.user = user
    }

    var userId: String {
        user.id
    }

    func updateAttributes(updater: (_ previous: [String: String]) -> [String: String]) {
        let data = self.user.data
        user.data = updater(data)
    }
}

extension BKTUser {
    func toUser() -> User {
        return .init(id: self.id, data: self.attr)
    }
}

extension User {
    func toBKTUser() -> BKTUser {
        return .init(id: self.id, attr: self.data)
    }
}
