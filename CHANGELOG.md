<a name="v1.1.0"></a>
## [v1.1.0](https://github.com/osquery/osquery-toolchain/releases/tag/v1.1.0)

- Keep the LLVM libraries in the final stage. This change has been introduced to support code generators (i.e.: BPF) (be224c7)
- Add a Docker-based build script (be224c7)
- Add an option to keep intermediate stages (e1e283b)
- Update LLVM to version 9.0.1 (88f0611)
- Fix scan-build support (203e5d6)
- Implement AArch64 support (96c5875)

The following assets and hashes are included in this release.

```
9cc3980383e0626276d3762af60035f36ada5886389a1292774e89db013a2353  osquery-toolchain-1.1.0-x86_64.tar.xz
19efe094031b9eab31e49438df7ae7bae9c4e4fc65e94f94e35f8c0ee23fe57c  osquery-toolchain-1.1.0-aarch64.tar.xz
```

<a name="1.0.0"></a>
## [1.0.0](https://github.com/osquery/osquery-toolchain/releases/tag/1.0.0)

This is the first version of the `x86_64-osquery-linux-gnu` toolchain.
It is designed to build a release version of osquery such that the resulting binaries can be run on a large number of Linux flavors.

A LLVM compiler, minimal sysroot, and other required tools such as GCC's assembler are provided.

Versions used:
- linux headers 4.7.10
- zlib 1.2.11
- llvm 8.0.1
- gcc 8.3.0
- glibc 2.12.2
- binutils 2.30
- crosstool-ng 1.24.0

The following assets and hashes are included in this release.

```
cfa65cfcc40cd804d276a43a2c3a0031bd371b32d35404e53e5450170ac63a69  osquery-toolchain-1.0.0.tar.xz
```
