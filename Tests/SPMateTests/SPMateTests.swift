import XCTest
import SPMateFramework
import Hitch
import Flynn

final class SPMateTests: XCTestCase {
    
    private func projectPath() -> String {
        return #filePath
    }
    
    func testTestsList() throws {
        let expectation = XCTestExpectation(description: #function)
        let project = SwiftProject(path: projectPath())
        project.beTestsList(Flynn.any) { tests in
            print(tests)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
}
