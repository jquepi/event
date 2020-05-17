import Test
@testable import Fiber

import struct Foundation.Date

class ChannelTests: TestCase {
    func testChannel() {
        let channel = Channel<Int>()

        fiber {
            guard let value = channel.read() else {
                fail("channel.read() failed")
                return
            }
            expect(value == 42)
        }

        fiber {
            expect(channel.write(42) == true)
        }

        FiberLoop.current.run()
    }

    func testChannelClose() {
        let channel = Channel<Int>()

        channel.close()
        expect(channel.write(42) == false)
        expect(channel.read() == nil)
    }

    func testChannelHasReader() {
        let channel = Channel<Int>()

        fiber {
            expect(!channel.hasReaders)
            _ = channel.read()
            expect(!channel.hasReaders)
            expect(channel.queue.count == 0)
        }

        fiber {
            expect(channel.hasReaders)
            expect(channel.queue.count == 0)
            channel.write(42)
            expect(!channel.hasReaders)
            expect(channel.queue.count == 1)
        }

        FiberLoop.current.run()
    }

    func testChannelHasWriter() {
        let channel = Channel<Int>()

        fiber {
            expect(!channel.hasWriters)
            channel.write(42)
            expect(!channel.hasWriters)
        }

        fiber {
            expect(channel.hasWriters)
            _ = channel.read()
            expect(!channel.hasWriters)
        }

        FiberLoop.current.run()
    }

    func testChannelCapacity0() {
        let channel = Channel<Int>()

        fiber {
            expect(channel.isEmpty)
            expect(!channel.canWrite)
            expect(!channel.canRead)
        }

        FiberLoop.current.run()
    }

    func testChannelCapacity1() {
        let channel = Channel<Int>(capacity: 1)

        fiber {
            expect(channel.isEmpty)
            expect(channel.canWrite)
            expect(!channel.canRead)
            channel.write(1)
            expect(!channel.isEmpty)
            expect(!channel.canWrite)
            expect(channel.canRead)
            _ = channel.read()
            expect(channel.isEmpty)
            expect(channel.canWrite)
            expect(!channel.canRead)
        }

        FiberLoop.current.run()
    }

    func testChannelCloseNoReader() {
        let channel = Channel<Int>(capacity: 10)

        fiber {
            for i in 0..<10 {
                channel.write(i)
            }
            channel.close()
        }

        expect(channel.isEmpty)
        FiberLoop.current.run()
    }

    func testChannelCloseHasReader() {
        let channel = Channel<Int>(capacity: 10)

        var first: Int? = nil
        fiber {
            first = channel.read()
        }

        fiber {
            for i in 0..<10 {
                channel.write(i)
            }
            channel.close()
        }

        FiberLoop.current.run()
        expect(channel.isEmpty)
        expect(first == 0)
    }

    func testChannelCloseHasWaitingReader() {
        let channel = Channel<Int>()

        var result: Optional<Int> = 42
        fiber {
            result = channel.read()
        }

        fiber {
            channel.close()
        }

        FiberLoop.current.run()
        expect(result == nil)
    }

    func testChannelCloseHasWaitingWriter() {
        let channel = Channel<Int>()

        var result = true
        fiber {
            result = channel.write(42)
        }

        fiber {
            channel.close()
        }

        FiberLoop.current.run()
        expect(result == false)
    }
}
