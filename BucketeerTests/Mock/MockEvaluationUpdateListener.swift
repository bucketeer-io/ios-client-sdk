import Foundation
@testable import Bucketeer

final class MockEvaluationUpdateListener: EvaluationUpdateListener {
    let handler: (() -> Void)?

    init(handler: (() -> Void)? = nil) {
        self.handler = handler
    }

    func onUpdate() {
        handler?()
    }
}
