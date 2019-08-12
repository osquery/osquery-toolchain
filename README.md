# osquery-toolchain

Goals:
- Obtain a LLVM/Clang toolchain which is portable and which doesn't depend from libstdc++ or libgcc.
- The toolchain is compiled against an old glibc version (2.12.2), so that it runs on older distro.
- The toolchain lives in a sysroot folder which should be self sufficient.

Steps:
- Use crosstool-ng to compile a GCC static toolchain, ending up with GCC 8.3.0, which might be newer than the one available in the system.
- Compile an older libz/zlib which is compatible with the old glibc.
- Link all gcc binaries into the sysroot created by crosstool-ng, so that the sysroot can be used for the next steps
- Compile a first Clang and lld (stage0), which uses libstdc++.
- Use the stage0 Clang to compile a stage1 compiler-rt (builtins only).
- Use the stage0 Clang/lld to compile a stage1 libc++, which will use the previously compiled compiler-rt
- Use the stage0 Clang/lld to compile the rest of compiler-rt (\*san libraries) and compile them with compiler-rt builtins
- Use the stage0 Clang to compile a stage1 libunwind (static only)
- Use the stage0 Clang, libunwind, libc++/c++abi, compiler-rt builtins, all static, to build a final/full toolchain
