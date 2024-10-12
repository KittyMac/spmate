import Flynn
import SourceKittenFramework
import Foundation
import Hitch
import Studding

public class TestFunction: Codable {
    public var functionName: String
    public var filePath: String?
    public var fileOffset: Int64?
    
    init(functionName: String,
         filePath: String?,
         fileOffset: Int64?) {
        self.functionName = functionName
        self.filePath = filePath
        self.fileOffset = fileOffset
    }
}

public class TestClass: Codable {
    public var className: String
    public var tests: [TestFunction] = []
    
    init(className: String) {
        self.className = className
    }
}

public class TestResult: Codable {
    public var targetName: String
    public var className: String
    public var functionName: String
    public var result: String
    
    init(targetName: String,
         className: String,
         functionName: String,
         result: String) {
        self.targetName = targetName
        self.className = className
        self.functionName = functionName
        self.result = result
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
                                             fileOffset: function.bodyoffset)
                            )
                        }
                    }
                }
            }
        }
        
        returnCallback(allTestClasses)
    }
    
    internal func _beTestsRun(filter: String?,
                              _ returnCallback: @escaping ([TestResult]) -> ()) {
        let path = pathFor(executable: "swift")
        
        let outputPath = "/tmp/\(UUID().uuidString).xunit"
                
        var arguments: [String] = []
        arguments.append("test")
        arguments.append("--package-path")
        arguments.append(safePath)
        arguments.append("--parallel")
        arguments.append("--xunit-output")
        arguments.append(outputPath)
        if let filter = filter {
            arguments.append("--filter")
            arguments.append(filter)
        }
                        
        let task = Spawn(path: path,
                         arguments: arguments)
        
        task.nullStandardOutput()
        task.nullStandardError()
                
        task.run()
        
        task.wait()
        
        var allResults: [TestResult] = []
        
        if let results = Hitch(contentsOfFile: outputPath) {
            Studding.parsed(hitch: results) { root in
                guard let root = root else { return }
                guard let testcases = root["testsuite"]?.children else { return }
                
                for testcase in testcases {
                    guard let combinedName: HalfHitch = testcase.attr(name: "classname") else { continue }
                    guard let functionName: HalfHitch = testcase.attr(name: "name") else { continue }
                    // guard let time: HalfHitch = testcase.attr(name: "time") else { continue }
                    let result: String = testcase["failure"] == nil ? "success" : "failure"
                    
                    let combinedNameParts: [Hitch] = combinedName.components(separatedBy: ".")
                    let targetName = combinedNameParts[0]
                    let className = combinedNameParts[1]
                    
                    allResults.append(
                        TestResult(targetName: targetName.toString(),
                                   className: className.toString(),
                                   functionName: functionName.toString(),
                                   result: result)
                    )
                }
                
            }
        }
        
        try? FileManager.default.removeItem(atPath: outputPath)
        
        returnCallback(allResults)
    }
}
