import Foundation
@testable import Bucketeer

final class MockEventUpdateListener: EventUpdateListener {
    let handler: (([Event]) -> Void)?

    init(handler: (([Event]) -> Void)? = nil) {
        self.handler = handler
    }

    func onUpdate(events: [Event]) {
        handler?(events)
    }
}
