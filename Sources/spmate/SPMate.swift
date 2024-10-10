import Flynn
import SourceKittenFramework

public class SPMate: Actor {
    private let path: String
    
    public init(path: String) {
        self.path = path
    }
    
    internal func _beTestsList(_ returnCallback: ([String]) -> ()) {
        returnCallback([
            "testFunc1",
            "testFunc2",
            "testFunc3",
        ])
    }
}
