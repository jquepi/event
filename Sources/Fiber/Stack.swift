import Platform

#if os(macOS)
let SC_PAGE_SIZE = _SC_PAGE_SIZE
#else
let SC_PAGE_SIZE = Int32(_SC_PAGESIZE)
#endif

struct Stack {
    let pointer: UnsafeMutableRawPointer
    let size: Int
}

let pagesize = sysconf(SC_PAGE_SIZE)

extension Stack {
    private static let size = 64.kB

    // TODO: inject allocator
    static func allocate() -> Stack {
        let pointer = UnsafeMutableRawPointer.allocate(
            byteCount: size, alignment: pagesize)
        mprotect(pointer, pagesize, PROT_READ)
        return Stack(pointer: pointer, size: size)
    }

    func deallocate() {
        pointer.deallocate()
    }
}

extension Int {
    var kB: Int {
        return self * 1024
    }
}
