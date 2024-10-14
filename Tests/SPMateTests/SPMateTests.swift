import XCTest
import SPMateFramework
import Hitch
import Flynn

final class SPMateTests: XCTestCase {
    
    private func projectPath() -> String {
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
    }
    
    func testTestsList() throws {
        let expectation = XCTestExpectation(description: #function)
        let project = SwiftProject(path: projectPath())
        project.beTestsList(Flynn.any) { tests in
            XCTAssertEqual(tests.first?.className, "SPMateTests")
            print(try! tests.json(pretty: true))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testTestsRun() throws {
        // NOTE: running swift test from a swtf unit test results in a hang (probably for safety reasons)
    }
    
}
