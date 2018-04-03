import Async
import Foundation

public class FiberScheduler {
    private var fibers = [UnsafeMutablePointer<Fiber>]()
    private var scheduler: UnsafeMutablePointer<Fiber>
    private(set) var running: UnsafeMutablePointer<Fiber>

    init() {
        scheduler = UnsafeMutablePointer<Fiber>.allocate(capacity: 1)
        scheduler.initialize(to: Fiber(schedulerId: -1, pointer: scheduler))
        running = scheduler

        ready.reserveCapacity(128)
    }

    deinit {
        for fiber in fibers {
            fiber.pointee.deallocate()
            fiber.deallocate()
        }
        scheduler.deallocate()
    }

    var ready = [UnsafeMutablePointer<Fiber>]()
    var cache = [UnsafeMutablePointer<Fiber>]()

    public var hasReady: Bool {
        return ready.count > 0
    }

    public func async(_ task: @escaping AsyncTask) {
        let fiber: UnsafeMutablePointer<Fiber>

        if let cached = cache.popLast() {
            fiber = cached
        } else {
            fiber = UnsafeMutablePointer<Fiber>.allocate(capacity: 1)
            fiber.initialize(to: Fiber(id: fibers.count, pointer: fiber))
            fibers.append(fiber)
        }

        fiber.pointee.state = .none
        fiber.pointee.task = task
        fiber.pointee.caller = running
        call(fiber: fiber)
    }

    // NOTE: do not change fiber caller here
    func call(fiber: UnsafeMutablePointer<Fiber>) {
        let caller = running
        running = fiber
        fiber.pointee.transfer(from: caller)
    }

    @usableFromInline
    @discardableResult
    func suspend() -> Fiber.State {
        let child = running
        guard let parent = child.pointee.caller else {
            fatalError("can't yield from the outside of a fiber")
        }
        running = parent
        child.pointee.caller = scheduler
        child.pointee.state = .sleep
        child.pointee.yield(to: parent)
        return running.pointee.state
    }

    @usableFromInline
    @discardableResult
    func yield() -> Fiber.State {
        ready.append(running)
        return suspend()
    }

    func lifecycle() {
        while true {
            let fiber = running

            guard let task = fiber.pointee.task else {
                fatalError("fiber task can't be nil")
            }

            task()

            fiber.pointee.task = nil
            fiber.pointee.state = .cached
            cache.append(fiber)

            suspend()
        }
    }

    func cancelReady() {
        for fiber in ready {
            fiber.pointee.state = .canceled
        }
    }

    @usableFromInline
    func schedule(fiber: UnsafeMutablePointer<Fiber>, state: Fiber.State)
    {
        fiber.pointee.state = state
        ready.append(fiber)
    }

    func runReadyChain() {
        assert(ready.count > 0)
        assert(running == scheduler)

        let first = ready.first!
        var last = first

        for next in ready.suffix(from: 1) {
            last.pointee.caller = next
            last = next
        }
        last.pointee.caller = running

        ready.removeAll(keepingCapacity: true)
        call(fiber: first)
    }
}
