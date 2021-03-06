# osquery-toolchain
The script in this repository is used to build the LLVM/Clang toolchain which is used in the osquery project to create portable binaries of it.  
The procedure to build such a toolchain has been based on the build-anywhere project: https://github.com/theopolis/build-anywhere

Following the main goals of the toolchain:
- Obtain a LLVM/Clang toolchain which is portable and which doesn't depend from libstdc++ or libgcc.
- The toolchain is compiled with a specific glibc version, so that it runs on a wide range of distributions.
- The toolchain lives in a sysroot folder which should be self sufficient.
- The toolchain should be able to produce binaries that are portable and run on libc >= 2.12.
  To do so, the output binary should depend only on shared libraries which are deeply connected with the environment they run on,
  typically libc, libdl, librt, libpthread.

The rough steps used to achieve the above goals:
- Use crosstool-ng to compile a stage0 GCC static toolchain, which might be newer than the one available in the system.
- Compile an older libz/zlib which is compatible with the old glibc.
- Link all GCC binaries into the sysroot created by crosstool-ng, so that the sysroot can be used for the next steps
- Compile a first Clang and lld (stage1), which uses libstdc++.
- Use the stage1 Clang to compile a stage1 compiler-rt (builtins only).
- Use the stage1 Clang/lld to compile a stage1 libc++, which will use the previously compiled compiler-rt
- Use the stage1 Clang/lld to compile the rest of compiler-rt (\*san libraries) and link them to the stage1 compiler-rt builtins
- Use the stage1 Clang to compile a stage1 libunwind (static only)
- Use the stage1 Clang, libunwind, libc++/c++abi, compiler-rt builtins, to build a final/full toolchain

The version of crosstool-ng used is 1.24.0
The version of the GCC compiler built by crosstool-ng is 8.3.0
The version of the libc library built by crosstool-ng is 2.12.2
The version of LLVM/Clang built by the script is 11.0.0
The version of the zlib library built by the script is 1.2.11

Among other, the toolchain LLVM/Clang includes the clang static analyzer, scan-build, clang-format, clang-tidy.

# How to build
Using a recent distribution with GCC 8 is suggested to reduce the possible crashes and issues that may happen when compiling
the portable GCC toolchain.  
For the instructions we will use Ubuntu 18.04.

## Prerequisites
```
sudo apt install g++-8 gcc-8 automake autoconf gettext bison flex unzip help2man libtool-bin libncurses-dev make ninja-build patch txinfo gawk wget git texinfo xz-utils python
```
Then use `update-alternatives` to tell the system that the version of GCC/G++ and CPP is the default we would like to use:
```
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 20
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-8 20
sudo update-alternatives --install /usr/bin/cpp cpp /usr/bin/cpp-8 20
```
Download and install CMake 3.17.5
```
wget https://github.com/Kitware/CMake/releases/download/v3.17.5/cmake-3.17.5-Linux-x86_64.tar.gz
sudo tar xvf cmake-3.17.5-Linux-x86_64.tar.gz -C /usr/local --strip 1
```

## Customize the configuration
The default configuration is ready to go, though if customization is needed, there are two files that can be modified: config and crosstool-ng-config.
- *config* contains global configuration values like, versions of llvm, zlib, how many parallel jobs to use, which build system to use and such.
- *crosstool-ng-config* contains the configuration that is feed into the crosstool-ng tool, which compiles the portable GCC.  
It controls the GCC version built, libc and kernel headers version to build everything.  
This is config normally generated by another tool that crosstool-ng provides, but the config can be manually modified after being generated.

## Build
The script has to be run as a normal user and accepts one argument, which is the folder where the various stages and the final toolchain will be built:
```
./build.sh /opt/osquery-toolchain
```
This should output the sysroot under `/opt/osquery-toolchain/final` and the LLVM toolchain will be under `/opt/osquery-toolchain/final/sysroot/usr`

## Redistributing and usage
1. Enter inside the **final** folder within the destination path
2. Rename the **sysroot** folder to **osquery-toolchain**
3. Compress the folder with the following command: `tar -pcvJf osquery-toolchain-<VERSION>.tar.xz osquery-toolchain`

Make sure that the **<VERSION>** field matches a valid tag, for example: `osquery-toolchain-1.0.1.tar.xz`.

The generated tarball can then be uncompressed wherever you like on the target machine.

The toolchain defaults to using libc++ as the C++ standard library, compiler-rt as part of the builtins it needs, instead of relying on libgcc and lld as the linker; so these are implicit.
libc++abi has to be explicitly linked when compiling C++ with `l:libc++abi.a` instead; merged with it there's also libunwind, which is therefore implicit.
Sometimes explicitly adding `-ldl` and/or `-lrt` is needed, depending on what functions the binary is using.
The only other flag that's needed is `--sysroot=<sysroot path>`, so that the toolchain searches what it needs in the correct path.

## Troubleshooting
If the compilation stops at any point in time, just relaunching the script should restart it.  
The script doesn't delete anything when it restarts the build, so if you want to start clean from some substep, you need to do that manually.

So for more advanced troubleshooting, following the build example in general we have:
- `/opt/osquery-toolchain/stage0`: here lives crosstool-ng source code, build, zlib source code, build and GCC/G++ toolchain compiled by crosstool-ng. The GCC/G++ toolchain folder is also copied on the next stages
- `/opt/osquery-toolchain/stage1`: here lives the intermediate LLVM/Clang toolchain, together with a copy of the previous step GCC/G++ toolchain and it's used to build the final toolchain
- `/opt/osquery-toolchain/final`: here lives the final sysroot containing only the LLVM/Clang toolchain we want to use
- `/opt/osquery-toolchain/llvm`: here lives the source code for the LLVM/Clang and the various build folders for the LLVM build substeps

The script decides it has to build one of the stages if it doesn't find a specific file in one of the install folders (stage0, stage1, final).
- For crosstool-ng is `/opt/osquery-toolchain/stage0/crosstool-ng/ct-ng`.
- For GCC is `/opt/osquery-toolchain/stage0/x86_64-osquery-linux-gnu/bin/x86_64-osquery-linux-gnu-gcc`
- For zlib is `/opt/osquery-toolchain/stage0/x86_64-osquery-linux-gnu/x86_64-osquery-linux-gnu/usr/lib/libz.a`
- For LLVM/Clang stage1 is `/opt/osquery-toolchain/stage0/x86_64-osquery-linux-gnu/x86_64-osquery-linux-gnu/sysroot/usr/bin/clang`
- For compiler-rt builtins is `/opt/osquery-toolchain/x86_64-osquery-linux-gnu/x86_64-osquery-linux-gnu/sysroot/usr/lib/clang/<clang version>/lib/linux/libclang_rt.builtins-x86_64.a`
- For libc++, libc++abi, libunwind, which are compiled together, is one of `/opt/osquery-toolchain/x86_64-osquery-linux-gnu/x86_64-osquery-linux-gnu/sysroot/usr/lib/libc++.a` `/opt/osquery-toolchain/x86_64-osquery-linux-gnu/x86_64-osquery-linux-gnu/sysroot/usr/lib/libc++abi.a` `/opt/osquery-toolchain/x86_64-osquery-linux-gnu/x86_64-osquery-linux-gnu/sysroot/usr/lib/libunwind.a`
- For the LLVM/Clang and respective libraries of the final stage is `/opt/osquery-toolchain/final/sysroot/usr/bin/clang`, because the install step is a single unit.
