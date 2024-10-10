import Foundation
import Spanker
import Flynn
import Hitch

// Provides a simple C interface for maximum compatibility

public typealias VoidPtr = UnsafePointer<UInt8>
public typealias UTF8Ptr = UnsafePointer<UInt8>
public typealias CallbackPtr = @convention(c) (VoidPtr?, UTF8Ptr?) -> ()

var spmRefereces: [String: SPMate] = [:]
let lock = NSLock()

@_cdecl("spmate_new")
public func spmate_new(path: String) -> String {
    lock.lock(); defer { lock.unlock() }
    let spmate = SPMate(path: path)
    spmRefereces[spmate.unsafeUUID] = spmate
    return spmate.unsafeUUID
}

@_cdecl("spmate_release")
public func spmate_release(reference: String) {
    lock.lock(); defer { lock.unlock() }
    spmRefereces.removeValue(forKey: reference)
}

@_cdecl("spmate_tests_list")
public func spmate_tests_list(reference: String,
                              _ returnCallback: CallbackPtr?,
                              _ returnInfo: VoidPtr?) {
    lock.lock(); defer { lock.unlock() }
    guard let spmate = spmRefereces[reference] else {
        returnCallback?(returnInfo, cError(message: "unknown reference"))
        return
    }
    
    spmate.beTestsList(Flynn.any) { results in
        let json = JsonElement(unknown: results).toHitch()
        returnCallback?(returnInfo, json.export().0)
    }
}

private func cError(message: String) -> UTF8Ptr? {
    let json = JsonElement(unknown: [
        "error": message
    ]).toHitch()
    return json.export().0
}
