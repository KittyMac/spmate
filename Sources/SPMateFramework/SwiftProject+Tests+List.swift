import Flynn
import SourceKittenFramework
import Foundation
import Hitch
import Sextant

public class ProjectTestTarget: Codable {
    public var targetName: String
    public var targetPath: String
    
    init(targetName: String,
         targetPath: String) {
        self.targetName = targetName
        self.targetPath = targetPath
    }
}

extension SwiftProject {
    private func getPackageTestTargets() -> [ProjectTestTarget] {
        var allTestTargets: [ProjectTestTarget] = []
        
        let path = pathFor(executable: "swift")
        let projectPath = safePath
        
        var arguments: [String] = []
        arguments.append("package")
        arguments.append("dump-package")
        arguments.append("--package-path")
        arguments.append(projectPath)
        let outPipe = SafePipe()!
        let task = Spawn(path: path,
                         arguments: arguments)
        task.setStandardOutput(outPipe)
        task.nullStandardError()
        
        task.terminationHandler = { _, _ in
            outPipe.fileHandleForWriting.closeFile()
        }

        task.run()
        
        if let result = outPipe.fileHandleForReading.read(upToCount: 1024 * 1024 * 32) {
            // print(Hitch(data: result))
            
            result.query(forEach: "$..targets[?(@.type == 'test')]") { root in
                guard let targetName = root[string: "name"] else { return }
                
                // NOTE: swift package dump-package does not currently export path if overridden
                allTestTargets.append(
                    ProjectTestTarget(targetName: targetName,
                                      targetPath: safePath + "/Tests/" + targetName + "/")
                )
            }
        }
        
        task.wait()
        
        return allTestTargets
    }
    
    internal func _beTestsList(_ returnCallback: ([TestFunction]) -> ()) {
        
        let allTestTargets = getPackageTestTargets()
        var allTests: [TestFunction] = []

        let testsASTBuilder = ASTBuilder()
        testsASTBuilder.add(directory: safePath + "/Tests/")
        
        let ast = testsASTBuilder.build()
        for (className, classSyntax) in ast.classes {
            if ast.isSubclassOf(classSyntax, "XCTestCase") {
                
                // find all functions which start with test
                if let functions = classSyntax.structure.substructure {
                    for function in functions {
                        if let functionName = function.name,
                           functionName.hasPrefix("test"),
                           function.kind == .functionMethodInstance {
                            
                            // functionName(argument:)
                            // we only want the base name
                            let regex = #"^([\d\w]+)\("#
                            functionName.matches(regex) { (_, groups) in
                                guard groups.count == 2 else { return }
                                
                                // find the right target name for this source file
                                for testTarget in allTestTargets {
                                    if classSyntax.file.path!.hasPrefix(testTarget.targetPath) {
                                        allTests.append(
                                            TestFunction(targetName: testTarget.targetName,
                                                         className: className,
                                                         functionName: groups[1],
                                                         filePath: classSyntax.file.path,
                                                         fileOffset: function.bodyoffset)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        returnCallback(allTests)
    }
}
