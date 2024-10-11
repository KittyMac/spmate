import Flynn
import SourceKittenFramework

public class SwiftProject: Actor {
    internal let safePath: String
    
    public init(path: String) {
        self.safePath = path
        super.init()
    }
}
