import Test
import Platform
@testable import Fiber

import struct Foundation.Date

class DispatchTests: TestCase {
    func testDispatch() {
        let loop = FiberLoop.current

        var iterations: Int = 0
        var result: Int = 0

        fiber {
            while iterations < 10 {
                iterations += 1
                // tick tock tick tock
                sleep(until: Date().addingTimeInterval(0.1))
            }
        }

        fiber {
            do {
                result = try dispatch {
                    // block thread
                    sleep(1)
                    return 42
                }
                loop.break()
            } catch {
                fail(String(describing: error))
            }
        }

        loop.run()
        assertEqual(result, 42)
        assertEqual(iterations, 10)
    }

    struct SomeError: Error, Equatable {
        let code: Int

        static func ==(lhs: SomeError, rhs: SomeError) -> Bool {
            return lhs.code == rhs.code
        }
    }

    func testDispatchThrow() {
        var taskError: Error? = nil

        fiber {
            do {
                _ = try dispatch {
                    throw SomeError(code: 42)
                }
            } catch {
                taskError = error
            }
        }

        FiberLoop.current.run()
        assertNotNil(taskError)
        if let error = taskError {
            assertEqual(error as? SomeError, SomeError(code: 42))
        }
    }
}
