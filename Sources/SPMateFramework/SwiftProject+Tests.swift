import Flynn
import SourceKittenFramework
import Foundation

public class TestFunction: Codable {
    public var functionName: String
    public var filePath: String?
    public var fileLine: Int64?
    
    init(functionName: String,
         filePath: String?,
         fileLine: Int64?) {
        self.functionName = functionName
        self.filePath = filePath
        self.fileLine = fileLine
    }
}

public class TestClass: Codable {
    public var className: String
    public var tests: [TestFunction] = []
    
    init(className: String) {
        self.className = className
    }
}

extension SwiftProject {
    internal func _beTestsList(_ returnCallback: ([TestClass]) -> ()) {
        let astBuilder = ASTBuilder()
        astBuilder.add(directory: safePath + "/Tests")
                
        let ast = astBuilder.build()
        
        // Find all classes which descend from XCTestCase
        var allTestClasses: [TestClass] = []
        
        for (className, classSyntax) in ast.classes {
            if ast.isSubclassOf(classSyntax, "XCTestCase") {
                
                let testClass = TestClass(className: className)
                allTestClasses.append(testClass)
                
                // find all functions which start with test
                if let functions = classSyntax.structure.substructure {
                    for function in functions {
                        if let functionName = function.name,
                           functionName.hasPrefix("test"),
                           function.kind == .functionMethodInstance {
                            testClass.tests.append(
                                TestFunction(functionName: functionName,
                                             filePath: classSyntax.file.path,
                                             fileLine: function.bodyoffset)
                            )
                        }
                    }
                }
            }
        }
        
        returnCallback(allTestClasses)
    }
}
