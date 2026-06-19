import Foundation
import CoreServices

public final class FolderWatcher {
    private var streamRef: FSEventStreamRef?
    private let callback: () -> Void
    private let queue: DispatchQueue
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceQueue = DispatchQueue(label: "com.declutter.watcher.debounce")
    private let debounceDelay: TimeInterval

    public init(paths: [String], queue: DispatchQueue = .main, debounceDelay: TimeInterval = 2.0, callback: @escaping () -> Void) {
        self.callback = callback
        self.queue = queue
        self.debounceDelay = debounceDelay
        
        let absolutePaths = paths.map { path -> String in
            if path.hasPrefix("/") {
                return path
            } else {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                return home + "/" + path
            }
        } as CFArray
        
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let callbackFunction: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let clientCallBackInfo = clientCallBackInfo else { return }
            let watcher = Unmanaged<FolderWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            watcher.handleEvent()
        }
        
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        
        streamRef = FSEventStreamCreate(
            kCFAllocatorDefault,
            callbackFunction,
            &context,
            absolutePaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            flags
        )
        
        if let stream = streamRef {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }
    
    private func handleEvent() {
        debounceWorkItem?.cancel()
        
        let task = DispatchWorkItem { [weak self] in
            self?.callback()
        }
        debounceWorkItem = task
        debounceQueue.asyncAfter(deadline: .now() + debounceDelay, execute: task)
    }
    
    deinit {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        debounceWorkItem?.cancel()
    }
}
