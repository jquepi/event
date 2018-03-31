import Test
import Fiber
import Platform
import Dispatch

@testable import Async
@testable import Fiber

import struct Foundation.Date

class AsyncTests: TestCase {
    override func setUp() {
        async.setUp(Fiber.self)
    }

    func testTask() {
        var done = false
        async.task {
            done = true
        }
        assertTrue(done)
    }

    func testSyncTask() {
        var tested = false

        var iterations: Int = 0
        var result: Int = 0

        async.task {
            while iterations < 10 {
                iterations += 1
                // tick tock tick tock
                async.sleep(until: Date().addingTimeInterval(0.1))
            }
        }

        async.task {
            do {
                result = try async.syncTask {
                    // block thread
                    sleep(1)
                    return 42
                }
                assertEqual(result, 42)
                assertEqual(iterations, 10)
                tested = true
            } catch {
                fail(String(describing: error))
            }
        }

        async.loop.run()
        assertTrue(tested)
    }

    func testSyncTaskCancel() {
        var taskDone = false
        var syncTaskDone = false

        var error: Error? = nil

        async.task {
            assertNotNil(try? async.testCancel())
            // the only way right now to cancel the fiber. well, all of them.
            async.loop.terminate()
            assertNil(try? async.testCancel())
        }

        async.task {
            do {
                try async.syncTask {
                    async.loop.terminate()
                    try async.testCancel()
                    syncTaskDone = true
                }
            } catch let taskError {
                error = taskError
            }

            taskDone = true
        }

        async.loop.run()

        assertEqual(error as? AsyncError, .taskCanceled)
        assertTrue(taskDone)
        assertFalse(syncTaskDone)
    }

    func testAwaiterDeadline() {
        var asyncError: AsyncError? = nil
        async.task {
            do {
                let descriptor = Descriptor(rawValue: 0)!
                try async.wait(for: descriptor, event: .read, deadline: Date())
            } catch {
                asyncError = error as? AsyncError
            }
        }

        async.loop.run()
        assertEqual(asyncError, .timeout)
    }
}
