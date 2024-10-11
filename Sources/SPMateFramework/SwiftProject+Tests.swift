import Flynn
import SourceKittenFramework
import Foundation

extension SwiftProject {
    internal func safeRefreshTests() {
        let astBuilder = ASTBuilder()
        astBuilder.add(directory: safePath + "/Tests")
                
        let ast = astBuilder.build()
        
        // find all classes which are descendants of XCTestCase
        for (className, classSyntax) in ast.classes {
            if ast.isSubclassOf(classSyntax, "XCTestCase") {
                print("\(className) is a subclass of XCTestCase")
            }
        }
    }
    
    internal func _beTestsList(_ returnCallback: ([String]) -> ()) {
        returnCallback([
            "testFunc1",
            "testFunc2",
            "testFunc3",
        ])
    }
}
