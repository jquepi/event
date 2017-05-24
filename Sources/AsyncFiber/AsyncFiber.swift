import Fiber

@_exported import Async

import struct Foundation.Date
import struct Dispatch.DispatchQoS

public struct AsyncFiber: Async {
    public init() {}

    public var loop: AsyncLoop = Loop()
    public var awaiter: IOAwaiter? = Awaiter()

    public func task(_ closure: @escaping AsyncTask) -> Void {
        fiber(closure)
    }

    public func syncTask<T>(
        qos: DispatchQoS.QoSClass = .background,
        deadline: Date = Date.distantFuture,
        task: @escaping () throws -> T
    ) throws -> T {
        return try dispatch(qos: qos, deadline: deadline, task: task)
    }

    public func sleep(until deadline: Date) {
        FiberLoop.current.wait(for: deadline)
    }

    public func testCancel() throws {
        yield()
        if FiberLoop.current.isCanceled {
            throw AsyncTaskCanceled()
        }
    }
}

extension AsyncFiber {
    public struct Loop: AsyncLoop {
        public func run() {
            FiberLoop.current.run()
        }

        public func run(until date: Date) {
            FiberLoop.current.run(until: date)
        }

        public func `break`() {
            FiberLoop.current.break()
        }
    }
}

extension AsyncFiber {
    public struct Awaiter: IOAwaiter {
        public init() {}

        public func wait(
            for descriptor: Descriptor,
            event: IOEvent,
            deadline: Date = Date.distantFuture
        ) throws {
            try FiberLoop.current.wait(
                for: descriptor,
                event: event,
                deadline: deadline)
        }
    }
}
