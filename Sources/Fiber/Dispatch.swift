import Async
import Platform
import Dispatch

import struct Foundation.Date

extension FiberLoop {
    public func syncTask<T>(
        onQueue queue: DispatchQueue = DispatchQueue.global(),
        qos: DispatchQoS = .background,
        deadline: Date = Date.distantFuture,
        task: @escaping () throws -> T
    ) throws -> T {
        var result: T? = nil
        var error: Error? = nil

        let fd = try pipe()

        try wait(for: fd.1, event: .write, deadline: deadline)

        let workItem = DispatchWorkItem(qos: qos) {
            fiber {
                do {
                    result = try task()
                } catch let taskError {
                    error = taskError
                }
            }
            FiberLoop.current.run()
            var done: UInt8 = 1
            write(fd.1.rawValue, &done, 1)
        }

        queue.async(execute: workItem)

        try wait(for: fd.0, event: .read, deadline: deadline)

        close(fd.0.rawValue)
        close(fd.1.rawValue)

        if let result = result {
            return result
        } else if let error = error {
            throw error
        } else if currentFiber.pointee.state == .canceled {
            throw AsyncError.taskCanceled
        }

        fatalError()
    }

    fileprivate func pipe() throws -> (Descriptor, Descriptor) {
        var fd: (Int32, Int32) = (0, 0)
        let pointer = UnsafeMutableRawPointer(&fd)
            .assumingMemoryBound(to: Int32.self)
        guard Platform.pipe(pointer) != -1 else {
            throw SystemError()
        }
        return (Descriptor(rawValue: fd.0)!, Descriptor(rawValue: fd.1)!)
    }
}
