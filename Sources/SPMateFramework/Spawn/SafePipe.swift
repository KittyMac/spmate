import Foundation
import Hitch

#if canImport(Glibc)
private let posix_lseek = Glibc.lseek
private let posix_write = Glibc.write
private let posix_read = Glibc.read
private let posix_close = Glibc.close
private let posix_pipe = Glibc.pipe
#endif
#if canImport(Darwin)
private let posix_lseek = Darwin.lseek
private let posix_write = Darwin.write
private let posix_read = Darwin.read
private let posix_close = Darwin.close
private let posix_pipe = Darwin.pipe
#endif

public class SafePipe {
    private var readEnd: SafeFileHandle
    private var writeEnd: SafeFileHandle

    init?() {
        var fds: [Int32] = [0, 0]
        if pipe(&fds) != 0 {
            return nil
        }
        
        readEnd = SafeFileHandle(fd: fds[0], closeOnDealloc: true)
        writeEnd = SafeFileHandle(fd: fds[1], closeOnDealloc: true)
    }
    
    var fileHandleForReading: SafeFileHandle {
        return readEnd
    }

    var fileHandleForWriting: SafeFileHandle {
        return writeEnd
    }

    deinit {
        readEnd.closeFile()
        writeEnd.closeFile()
    }
}

