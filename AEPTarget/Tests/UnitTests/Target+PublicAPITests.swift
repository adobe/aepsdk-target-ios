/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

@testable import AEPCore
@testable import AEPTarget
import XCTest

class TargetPublicAPITests: XCTestCase {
    override func setUp() {
        MockExtension.reset()
        EventHub.shared.start()
        registerMockExtension(MockExtension.self)
    }

    private func registerMockExtension<T: Extension>(_ type: T.Type) {
        let semaphore = DispatchSemaphore(value: 0)
        EventHub.shared.registerExtension(type) { _ in
            semaphore.signal()
        }

        semaphore.wait()
    }

    func testPrefetchContent() throws {
        let expectation = XCTestExpectation(description: "prefetchContent should dispatch an event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            guard let eventData = event.data, let prefetchArray = TargetPrefetch.from(dictionaries: eventData["prefetch"] as? [[String: Any]]),
                  let parameters = TargetParameters.from(dictionary: eventData["targetparams"] as? [String: Any])
            else {
                return
            }
            XCTAssertEqual(2, prefetchArray.count)
            XCTAssertTrue([prefetchArray[0].name, prefetchArray[1].name].contains("Drink_1"))
            XCTAssertTrue([prefetchArray[0].name, prefetchArray[1].name].contains("Drink_2"))
            XCTAssertEqual("Smith", parameters.profileParameters?["name"])
            expectation.fulfill()
        }

        Target.prefetchContent(
            prefetchObjectArray: [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"]),
            completion: nil
        )
        wait(for: [expectation], timeout: 1)
    }

    func testPrefetchContent_with_empty_PrefetchObjectArray() throws {
        let expectation = XCTestExpectation(description: "error callback")
        expectation.assertForOverFulfill = true
        Target.prefetchContent(prefetchObjectArray: [], targetParameters: TargetParameters(profileParameters: ["name": "Smith"])) { error in
            guard let error = error as? TargetError else {
                return
            }
            XCTAssertEqual("Empty or nil prefetch requests list", error.description)
            expectation.fulfill()
        }
    }

    func testPrefetchContent_with_error_response() throws {
        let expectation = XCTestExpectation(description: "prefetchContent should dispatch an event")
        expectation.assertForOverFulfill = true
        EventHub.shared.getExtensionContainer(MockExtension.self)?.registerListener(type: EventType.target, source: EventSource.requestContent) { event in
            EventHub.shared.dispatch(event: event.createResponseEvent(name: "", type: "", source: "", data: ["prefetcherror": "unexpected error"]))
        }
        Target.prefetchContent(
            prefetchObjectArray: [
                TargetPrefetch(name: "Drink_1", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
                TargetPrefetch(name: "Drink_2", targetParameters: TargetParameters(profileParameters: ["mbox-parameter-key1": "mbox-parameter-value1"])),
            ],
            targetParameters: TargetParameters(profileParameters: ["name": "Smith"])
        ) { error in
            guard let error = error as? TargetError else {
                return
            }
            XCTAssertEqual("unexpected error", error.description)
            expectation.fulfill()
        }
    }
}
