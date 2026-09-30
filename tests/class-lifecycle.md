# Standalone class-address lifecycle regression

Compile without ARC against the runtime under test, linking libobjc and libSystem
but not Foundation or AppKit. For a native Darwin toolchain, the basic command is:

```sh
clang -fno-objc-arc class-lifecycle.m -lobjc -o class-lifecycle
./class-lifecycle
```

For the Darling ARM64 high-address variant, add
`-Wl,-image_base,0x700000000000` when linking and run with
`OBJC_MIN_CLASS_ADDRESS=0x700000000000`. Check the actual address printed and the
final PASS marker; the fixture asserts the class lies at or above the requested
minimum and below 2^47. A launcher that relocates it lower must fail this check.
The linker/loader must support this placement; no native macOS run is claimed.

The fixture covers 100 cycles of class identity, dispatch, retained weak loads,
destruction and weak zeroing. It requires manual reference counting and keeps
assertions enabled even when NDEBUG is passed. It does not test arm64e signatures,
addresses above 2^47, arbitrary allocator placement, concurrency or all weak APIs.

Validated in an ARM64 Darling guest against upstream objc f3cd60dd: ordinary
class address 0x10000c158 and high class address around 0x70000000c168 pass. The
guest uses a coordinated partial rebuild and staged support libraries, including
the loader segment-slide fix proposed in darling#1024. This standalone regression
does not change production code or claim the entire upstream system is buildable.
