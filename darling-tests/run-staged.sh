#!/usr/bin/env bash
# Run a prelinked ARM64 fixture in an isolated, disposable staged prefix.
# Usage: bash darling-tests/run-staged.sh INSTALL_ROOT BINARY raw|lookup|concurrent [LIBOBJC]
set -euo pipefail
install_root=$(realpath "${1:?staged install root required}")
binary=$(realpath "${2:?ARM64 Mach-O fixture required}")
mode=${3:?raw, lookup or concurrent required}
case "$mode" in raw|lookup|concurrent) ;; *) exit 2 ;; esac
[[ $(uname -m) == aarch64 && -x "$binary" && -x "$install_root/bin/darlingserver" ]]
image=${DARLING_ARM64_IMAGE:-darling-arm64-dev:latest}
container="codex-objc-allocation-${mode}-$$"
override=()
if [[ -n ${4:-} ]]; then
    runtime=$(realpath "$4")
    [[ -f "$runtime" ]]
    sha256sum "$runtime"
    override=(-e OBJC_AUDIT_OVERRIDE=1 -v "$runtime:/opt/libobjc.A.dylib:ro")
fi
output=$(docker run --rm --name "$container" \
    "${override[@]}" \
    -e DARLING_ARM64_THREAD_BRIDGE=1 -e OBJC_RAW_ALLOCATION_MODE="$mode" \
    --cap-add SYS_ADMIN --cap-add SYS_PTRACE \
    --security-opt apparmor=unconfined --security-opt seccomp=unconfined \
    -v "$install_root/root:/usr/local/libexec/darling:ro" \
    -v "$install_root/bin:/opt/darling/bin:ro" \
    -v "$binary:/opt/probe:ro" "$image" bash -lc '
        set -e
        prefix=/tmp/darling-prefix
        mkdir -p "$prefix/dev/pts"
        cp -a /dev/null /dev/urandom "$prefix/dev/"
        mount --bind /dev/pts "$prefix/dev/pts"
        ln -s pts/ptmx "$prefix/dev/ptmx"
        cp /opt/probe "$prefix/objc-raw-allocation"
        if [[ ${OBJC_AUDIT_OVERRIDE:-0} == 1 ]]; then
            mkdir -p "$prefix/usr/lib"
            cp /opt/libobjc.A.dylib "$prefix/usr/lib/libobjc.A.dylib"
        fi
        export PATH=/opt/darling/bin:$PATH
        export DARLING_NOOVERLAYFS=1 DYLD_USE_CLOSURES=0
        export DSERVER_INIT=/objc-raw-allocation
        exec timeout 15s darlingserver "$prefix" 0 0 1 0
    ' 2>&1) || { status=$?; printf '%s\n' "$output"; exit "$status"; }
printf '%s\n' "$output"
# Server exit status alone did not establish that the fixture completed.
grep -Fq "PASS: $mode allocation, instance identity/size, nil input and disposal" <<<"$output"
