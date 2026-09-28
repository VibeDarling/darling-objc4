# Allocation regression

`raw-allocation.m` addresses a compiler-emitted root class directly. `raw` mode
requires it to be unrealized before allocation; exit 77 means that precondition
was not met. `lookup` mode is the control: objc_getClass realizes the class first.
Both exercise nil input, extra instance bytes, object identity and disposal.
Run each in a fresh process. This fixture excludes arm64e and 32-bit metadata.

On a Darwin-compatible development environment, link against the runtime under test:

```sh
clang -fno-objc-arc darling-tests/raw-allocation.m -lobjc -o raw-allocation
./raw-allocation raw
./raw-allocation lookup
```

For an existing native ARM64 Darling stage build, `build-isolated.rb` recompiles
all sources listed in this checkout's runtime/CMakeLists.txt. It reuses stage
compiler options and SDK/dependency libraries, so it is not a clean parent build.
It assumes the parent Ninja objc_obj target names and /work/source, /work/build
path layout. Supply absolute paths and a new output directory:

```sh
ruby darling-tests/build-isolated.rb CHECKOUT STAGE_BUILD LOCAL_SOURCE NEW_OUTPUT
```

Compile/link the fixture for ARM64 with the stage SDK/cctools linker, libobjc and
libSystem; use the complete installed root as the linker syslibroot for reexports.
Then run the prelinked fixture with a selected dylib override:

```sh
bash darling-tests/run-staged.sh INSTALL_ROOT FIXTURE_BINARY raw NEW_OUTPUT/libobjc.A.dylib
bash darling-tests/run-staged.sh INSTALL_ROOT FIXTURE_BINARY lookup NEW_OUTPUT/libobjc.A.dylib
```

The runner needs Docker and the existing darling-arm64-dev image (override with
DARLING_ARM64_IMAGE). It uses the stage runner's container capabilities, mounts
the staged install read-only, and copies the selected runtime and fixture into a
disposable prefix. It requires the fixture's PASS marker, not merely server exit
zero. No installed runtime is overwritten. Build logs remain in NEW_OUTPUT.

These helpers are standalone and not wired into objc4's Apple test harness.
The fixture does not cover Swift initialization, concurrent allocation or the
internal root/batch/zone allocation entry points.
