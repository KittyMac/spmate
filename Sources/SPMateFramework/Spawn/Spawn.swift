// API similar replacement for Process() - works around crash bugs with Linux Process() implementation
import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

func pathFor(executable name: String) -> String {
    if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/\(name)") {
        return "/opt/homebrew/bin/\(name)"
    } else if FileManager.default.fileExists(atPath: "/usr/bin/\(name)") {
        return "/usr/bin/\(name)"
    } else if FileManager.default.fileExists(atPath: "/usr/local/bin/\(name)") {
        return "/usr/local/bin/\(name)"
    } else if FileManager.default.fileExists(atPath: "/bin/\(name)") {
        return "/bin/\(name)"
    }
    return "./\(name)"
}

public class Spawn {
    var cpid: pid_t = 0
    
    let path: String
    let arguments: [String]
    
    private var standardInputFd: [Int32] = [-1, -1]
    private var standardOutputFd: [Int32] = [-1, -1]
    private var standardErrorFd: [Int32] = [-1, -1]
    
    func setStandardInput(_ pipe: SafePipe) {
        standardInputFd[0] = pipe.fileHandleForReading.fileDescriptor
        standardInputFd[1] = pipe.fileHandleForWriting.fileDescriptor
    }
    func setStandardInput(_ pipe: Pipe) {
        standardInputFd[0] = pipe.fileHandleForReading.fileDescriptor
        standardInputFd[1] = pipe.fileHandleForWriting.fileDescriptor
    }
    
    func setStandardOutput(_ pipe: SafePipe) {
        standardOutputFd[0] = pipe.fileHandleForReading.fileDescriptor
        standardOutputFd[1] = pipe.fileHandleForWriting.fileDescriptor
    }
    func setStandardOutput(_ pipe: Pipe) {
        standardOutputFd[0] = pipe.fileHandleForReading.fileDescriptor
        standardOutputFd[1] = pipe.fileHandleForWriting.fileDescriptor
    }

    func setStandardError(_ pipe: SafePipe) {
        standardErrorFd[0] = pipe.fileHandleForReading.fileDescriptor
        standardErrorFd[1] = pipe.fileHandleForWriting.fileDescriptor
    }
    func setStandardError(_ pipe: Pipe) {
        standardErrorFd[0] = pipe.fileHandleForReading.fileDescriptor
        standardErrorFd[1] = pipe.fileHandleForWriting.fileDescriptor
    }
    
    
    public var terminationHandler: ((Int32, String?) -> ())? = nil
    
    public init(path: String,
                arguments: [String]) {
        self.path = path
        self.arguments = arguments
    }
    
    public func wait() {
        guard cpid > 0 else {
            terminationHandler?(-3, "run not called")
            return
        }

        // wait
        var stat: Int32 = 0
        while true {
            let wpid = waitpid(cpid, &stat, 0)
            if wpid != -1  {
                break
            }
            if errno != EINTR {
                break
            }
        }
        
        // check termination reason
        let _WSTATUS = stat & 0177
        if _WSTATUS == 0 { // WIFEXITED
            #if __DARWIN_UNIX03
                let rstat = (stat >> 8) & 0x0000_00FF
            #else /* !__DARWIN_UNIX03 */
                let rstat = stat >> 8
            #endif

            terminationHandler?(rstat, nil)
            return
        } else if _WSTATUS == WSTOPPED { // WIFSTOPPED
            terminationHandler?(-1, "Execution of \(path) was stopped by signal \(stat >> 8)")
            return
        } else { // WIFSIGNALED
            if stat & WCOREFLAG != 0 {
                terminationHandler?(-2, "Core dumped when executing \(path).")
                return
            }
            terminationHandler?(_WSTATUS, "Unknown signal \(_WSTATUS)")
            return
        }
    }
    
    public func run() {
        guard cpid == 0 else {
            terminationHandler?(-1, "run called multiple times")
            return
        }
        
        var argv = arguments.map { strdup($0) }
        argv.insert(strdup(path), at: 0)
        argv.append(nil)
        
        // linux seems to use some weird initialization for those native types.
        // stolen from https://github.com/aciidb0mb3r/Spawn/blob/master/Sources/Spawn/Spawn.swift#L27
        #if os(OSX)
            var fa: posix_spawn_file_actions_t?
        #else
            var fa = posix_spawn_file_actions_t()
        #endif

        posix_spawn_file_actions_init(&fa)
                
        // setup stdin redirection
        if standardInputFd[0] != -1 && standardInputFd[1] != -1 {
            posix_spawn_file_actions_addclose(&fa, standardInputFd[1])
            posix_spawn_file_actions_adddup2(&fa, standardInputFd[0], 0)
            posix_spawn_file_actions_addclose(&fa, standardInputFd[0])
        }

        // setup stdout redirection
        if standardOutputFd[0] != -1 && standardOutputFd[1] != -1 {
            posix_spawn_file_actions_addclose(&fa, standardOutputFd[0])
            posix_spawn_file_actions_adddup2(&fa, standardOutputFd[1], 1)
            posix_spawn_file_actions_addclose(&fa, standardOutputFd[1])
        }

        // setup stderr redirection
        if standardErrorFd[0] != -1 && standardErrorFd[1] != -1 {
            posix_spawn_file_actions_addclose(&fa, standardErrorFd[0])
            posix_spawn_file_actions_adddup2(&fa, standardErrorFd[1], 2)
            posix_spawn_file_actions_addclose(&fa, standardErrorFd[1])
        }

        let perror = posix_spawnp(&self.cpid, path, &fa, nil, argv, environ)
        defer { posix_spawn_file_actions_destroy(&fa) }
        guard perror == 0 else {
            self.terminationHandler?(-3, "Execution of \(path) could not be started due to error code (\(perror))")
            return
        }
        
    }
    
    public func terminate() {
        kill(cpid, SIGTERM)
        wait()
    }
    
}
