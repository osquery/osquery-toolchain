#!/bin/bash
# Heavily influenced by https://github.com/theopolis/build-anywhere

function build_gcc() {
  # Clone and build CrosstoolNG.
  if [[ ! -d $CURRENT_DIR/crosstool-ng ]]; then
    ( cd $CURRENT_DIR; \
      git clone https://github.com/crosstool-ng/crosstool-ng -b crosstool-ng-1.24.0 --single-branch )
  fi

  # Use our own config that sets a legacy glibc.
  cp ./crosstool-ng-config $CURRENT_DIR/crosstool-ng/.config

  if [[ ! -f $CURRENT_DIR/crosstool-ng/ct-ng ]]; then
    ( cd $CURRENT_DIR/crosstool-ng; \
      ./bootstrap; \
      ./configure --enable-local; \
      make )
  fi

  # Build GCC_TOOLCHAIN.
  if [[ ! -e $CURRENT_DIR/$TUPLE/bin/$TUPLE-gcc ]]; then
    ( cd $CURRENT_DIR/crosstool-ng;
      CT_PREFIX=$CURRENT_DIR ./ct-ng build )
  fi
}

function prepare_sysroot() {

  if [[ ! -e $PREFIX/bin/gcc ]]; then
    # Create symlinks in the new sysroot to GCC.
    ( cd $PREFIX/bin; \
      for file in ../../../../bin/*; do ln -s $file ${file/*${TUPLE}-/} || true; done )
  fi
}

function build_zlib() {
  # Build a legacy zlib and install into the sysroot.
  if [[ ! -d $CURRENT_DIR/zlib-${ZLIB_VER} ]]; then
    ( cd $CURRENT_DIR; \
      wget $ZLIB_URL; \
      echo "${ZLIB_SHA} zlib-${ZLIB_VER}.tar.gz" | sha256sum -c; \
      tar xzf zlib-${ZLIB_VER}.tar.gz )
  fi

  if [[ ! -e $PREFIX/lib/libz.a ]]; then
    ( cd $CURRENT_DIR/zlib-${ZLIB_VER}; \
      CC=$TUPLE-gcc \
      CXX=$TUPLE-g++ \
      CFLAGS=--sysroot=$SYSROOT \
      LDFLAGS=--sysroot=$SYSROOT \
      ./configure --prefix $PREFIX;
      make -j $PARALLEL_JOBS; \
      make install )
  fi
}

function build_llvm() {

  if [[ ! -e ${install_dir}/bin/clang ]]; then

    echo "Building the following LLVM projects: ${llvm_projects}"

    ( cd $LLVM_SRC && \
      mkdir -p ${build_folder} && \
      cd ${build_folder} && \
      cmake -G ${BUILD_GENERATOR} \
            -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
            -DCMAKE_C_COMPILER=${cc_compiler} \
            -DCMAKE_CXX_COMPILER=${cxx_compiler} \
            -DCMAKE_INSTALL_PREFIX=${install_dir} \
            -DCMAKE_C_FLAGS="${additional_compiler_flags}" \
            -DCMAKE_CXX_FLAGS="${additional_compiler_flags}" \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SYSROOT="${SYSROOT}" \
            -DLLVM_REQUIRES_RTTI=ON \
            -DLLVM_TARGETS_TO_BUILD=${targets_to_build} \
            -DLLVM_ENABLE_PROJECTS="${llvm_projects}" \
            -DLLVM_BUILD_LLVM_DYLIB=ON \
            -DLLVM_LINK_LLVM_DYLIB=ON \
            -DLLVM_ENABLE_EH=ON \
            -DLLVM_ENABLE_RTTI=ON \
            -DLLVM_INCLUDE_DOCS=OFF \
            -DLLVM_INCLUDE_TESTS=OFF \
            -DLLVM_INCLUDE_EXAMPLES=OFF \
            -DLLVM_ENABLE_LIBXML2=OFF \
            -DLLVM_DEFAULT_TARGET_TRIPLE=${TUPLE} \
            ${additional_cmake} \
            ../llvm && \
      cmake --build . -j ${PARALLEL_JOBS} && \
      cmake --build . --target install -j ${PARALLEL_JOBS} \
    )

  fi
}

function build_compiler-rt-builtins() {

  if [[ ! -e ${install_dir}/lib/linux/libclang_rt.builtins-x86_64.a ]]; then

    ( cd $LLVM_SRC && \
      mkdir -p ${build_folder} && \
      cd ${build_folder} && \
      cmake -G ${BUILD_GENERATOR} \
            -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
            -DCMAKE_C_COMPILER=${cc_compiler} \
            -DCMAKE_CXX_COMPILER=${cxx_compiler} \
            -DCMAKE_INSTALL_PREFIX=${install_dir} \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SYSROOT="${SYSROOT}" \
            -DLLVM_BUILD_LLVM_DYLIB=ON \
            -DLLVM_LINK_LLVM_DYLIB=ON \
            -DLLVM_DEFAULT_TARGET_TRIPLE=${TUPLE} \
            -DLLVM_REQUIRES_RTTI=ON \
            -DLLVM_ENABLE_EH=ON \
            -DLLVM_ENABLE_RTTI=ON \
            -DLLVM_INCLUDE_DOCS=OFF \
            -DLLVM_INCLUDE_TESTS=OFF \
            -DLLVM_INCLUDE_EXAMPLES=OFF \
            -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
            -DCOMPILER_RT_BUILD_PROFILE=OFF \
            -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
            -DCOMPILER_RT_BUILD_XRAY=OFF \
            -DCOMPILER_RT_INCLUDE_TESTS=OFF \
            -DCOMPILER_RT_INSTALL_PATH=${install_dir} \
            ${additional_cmake} \
            ../compiler-rt && \
      cmake --build . -j ${PARALLEL_JOBS} && \
      cmake --build . --target install -j ${PARALLEL_JOBS} \
    )
  fi
}

function build_libunwind() {
  if [[ ! -e ${install_dir}/lib/libunwind.so ]]; then

    ( cd $LLVM_SRC && \
      mkdir -p ${build_folder} && \
      cd ${build_folder} && \
      cmake -G ${BUILD_GENERATOR} \
            -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
            -DCMAKE_C_COMPILER=${cc_compiler} \
            -DCMAKE_CXX_COMPILER=${cxx_compiler} \
            -DCMAKE_INSTALL_PREFIX=${install_dir} \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SYSROOT="${SYSROOT}" \
            -DLLVM_LINK_LLVM_DYLIB=ON \
            -DLLVM_ENABLE_EH=ON \
            -DLLVM_ENABLE_RTTI=ON \
            -DLLVM_INCLUDE_DOCS=OFF \
            -DLIBUNWIND_USE_COMPILER_RT=ON \
            ${additional_cmake} \
            ../libunwind && \
      cmake --build . -j ${PARALLEL_JOBS} && \
      cmake --build . --target install -j ${PARALLEL_JOBS} \
    )
  fi
}

#-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
function build_libcxx() {

  if [[ ! -e ${install_dir}/lib/libc++.a ]]; then
    ( cd $LLVM_SRC && \
      mkdir -p ${build_folder} && \
      cd ${build_folder} && \
      cmake -G ${BUILD_GENERATOR} \
            -DCMAKE_VERBOSE_MAKEFILE=ON \
            -DCMAKE_BUILD_TYPE=${LLVM_BUILD_TYPE} \
            -DCMAKE_C_COMPILER=${cc_compiler} \
            -DCMAKE_CXX_COMPILER=${cxx_compiler} \
            -DCMAKE_INSTALL_PREFIX=${install_dir} \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--strip-all ${additional_linker_flags}" \
            -DCMAKE_SYSROOT="${SYSROOT}" \
            -DLLVM_REQUIRES_RTTI=ON \
            -DLLVM_TARGETS_TO_BUILD=${targets_to_build} \
            -DLLVM_ENABLE_PROJECTS="${llvm_projects}" \
            -DLLVM_BUILD_LLVM_DYLIB=ON \
            -DLLVM_LINK_LLVM_DYLIB=ON \
            -DLLVM_ENABLE_EH=ON \
            -DLLVM_ENABLE_RTTI=ON \
            -DLLVM_INCLUDE_DOCS=OFF \
            -DLLVM_INCLUDE_TESTS=OFF \
            -DLLVM_INCLUDE_EXAMPLES=OFF \
            -DLLVM_ENABLE_LIBXML2=OFF \
            -DLLVM_DEFAULT_TARGET_TRIPLE=${TUPLE} \
            -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
            -DLIBCXXABI_ENABLE_STATIC_UNWINDER=ON \
            -DLIBCXXABI_USE_COMPILER_RT=ON \
            -DLIBCXXABI_ENABLE_SHARED=OFF \
            -DLIBCXXABI_ENABLE_STATIC=ON \
            -DLIBCXX_INCLUDE_TESTS=OFF \
            -DLIBCXX_ENABLE_STATIC=ON \
            -DLIBCXX_ENABLE_SHARED=OFF \
            -DLIBCXX_USE_COMPILER_RT=ON \
            -DLIBCXX_ENABLE_FILESYSTEM=ON \
            -DLIBUNWIND_USE_COMPILER_RT=ON \
            ${additional_cmake} \
            ../llvm && \
      cmake --build . --target cxx -j ${PARALLEL_JOBS} && \
      cmake --build . --target install-cxx -j ${PARALLEL_JOBS} && \
      cmake --build . --target install-cxxabi -j ${PARALLEL_JOBS} && \
      cmake --build . --target install-unwind -j ${PARALLEL_JOBS}
    )
  fi
}

set -e

source ./config

TOOLCHAIN_DIR=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

CURRENT_DIR=$TOOLCHAIN_DIR/stage0
mkdir -p $CURRENT_DIR

SYSROOT=$CURRENT_DIR/$TUPLE/$TUPLE/sysroot
PREFIX=$SYSROOT/usr


build_gcc
prepare_sysroot

export PATH=$CURRENT_DIR/$TUPLE/bin:$PATH
build_zlib

if [[ ! -d $TOOLCHAIN_DIR/stage1 ]]; then
  mkdir -p $TOOLCHAIN_DIR/stage1
  cp -r $CURRENT_DIR/$TUPLE $TOOLCHAIN_DIR/stage1/
fi

if [[ ! -d $TOOLCHAIN_DIR/final ]]; then
  mkdir -p $TOOLCHAIN_DIR/final
  cp -r $CURRENT_DIR/$TUPLE $TOOLCHAIN_DIR/final/
fi

STAGE1_SYSROOT=$TOOLCHAIN_DIR/stage1/$TUPLE/$TUPLE/sysroot
if [[ ! -L $STAGE1_SYSROOT/usr/lib/gcc ]]; then
  ( cd $STAGE1_SYSROOT/usr/lib; \
    ln -s ../../../../lib/gcc $STAGE1_SYSROOT/usr/lib )
fi

FINAL_SYSROOT=$TOOLCHAIN_DIR/final/$TUPLE/$TUPLE/sysroot
if [[ ! -L $FINAL_SYSROOT/usr/lib/gcc ]]; then
  ( cd $FINAL_SYSROOT/usr/lib; \
    ln -s ../../../../lib/gcc $FINAL_SYSROOT/usr/lib )
fi

CURRENT_DIR=$TOOLCHAIN_DIR/stage1
SYSROOT=$CURRENT_DIR/$TUPLE/$TUPLE/sysroot
PREFIX=$SYSROOT/usr
GCC_TOOLCHAIN=$CURRENT_DIR/$TUPLE
LLVM_SRC="$TOOLCHAIN_DIR/llvm"

export PKG_CONFIG_PATH=/lib/pkgconfig
export PATH=$PREFIX/bin:$PATH

if [[ ! -e  $PREFIX/lib/libstdc++.so ]]; then
  ( cd $PREFIX/lib; \
    for file in ../../lib/libstdc*; do ln -s $file $(basename $file) || true; done )
fi

if [[ ! -L $PREFIX/include/c++ ]]; then
  ( cd $PREFIX/include; \
    ln -s ../../../include/c++ $PREFIX/include/ )
fi

if [[ ! -d ${LLVM_SRC} ]]; then
  mkdir -p `dirname $LLVM_SRC`
  cd `dirname $LLVM_SRC`
  git clone https://github.com/llvm/llvm-project.git llvm -b llvmorg-$LLVM_VERSION --single-branch --depth 1
fi

LLVM_DISABLED_TOOLS="-DLLVM_TOOL_BUGPOINT_BUILD=OFF"
LLVM_DISABLED_TOOLS="${LLVM_DISABLED_TOOLS} -DLLVM_TOOL_BUGPOINT_PASSES_BUILD=OFF"
LLVM_DISABLED_TOOLS="${LLVM_DISABLED_TOOLS} -DLLVM_TOOL_DSYMUTIL_BUILD=OFF"
LLVM_DISABLED_TOOLS="${LLVM_DISABLED_TOOLS} -DLLVM_TOOL_GOLD_BUILD=OFF"
LLVM_DISABLED_TOOLS="${LLVM_DISABLED_TOOLS} -DLLVM_TOOL_LLVM_C_TEST_BUILD=OFF"
LLVM_DISABLED_TOOLS="${LLVM_DISABLED_TOOLS} -DLLVM_TOOL_LLVM_EXEGESIS_BUILD=OFF"

build_folder="build-llvm-stage0" \
cc_compiler="gcc" \
cxx_compiler="g++" \
install_dir="$PREFIX" \
llvm_projects='clang;lld' \
targets_to_build="X86" \
additional_linker_flags="" \
additional_compiler_flags="-s" \
additional_cmake="" \
build_llvm

# Remove the static libclang/liblld and shared libc++/libunwind libraries from the sysroot.
( cd $PREFIX/lib; \
  rm libclang*.a; \
  rm liblld*.a; \
  rm libc++*.so.*; \
  rm libunwind*.so.*)

build_folder="build-compilerrt-builtins" \
cc_compiler="clang" \
cxx_compiler="clang++" \
install_dir="$PREFIX/lib/clang/$LLVM_VERSION" \
additional_linker_flags="" \
additional_cmake="" \
build_compiler-rt-builtins

build_folder="build-libcxx" \
cc_compiler="clang" \
cxx_compiler="clang++" \
install_dir="$PREFIX" \
llvm_projects='libcxx;libcxxabi;libunwind' \
targets_to_build='X86;BPF' \
additional_linker_flags="" \
additional_cmake="" \
build_libcxx

build_folder="build-libcxx" \
cc_compiler="clang" \
cxx_compiler="clang++" \
install_dir="$TOOLCHAIN_DIR/final/$TUPLE/$TUPLE/sysroot/usr" \
llvm_projects='libcxx;libcxxabi;libunwind' \
targets_to_build='X86;BPF' \
additional_linker_flags="" \
additional_cmake="" \
build_libcxx

# We do not update the sysroot because we want to use the one from the previous stage
CURRENT_DIR=$TOOLCHAIN_DIR/final
PREFIX=$CURRENT_DIR/$TUPLE/$TUPLE/sysroot/usr

llvm_additional_cmake="-DCOMPILER_RT_INSTALL_PATH=${PREFIX}"
llvm_additional_cmake="${llvm_additional_cmake} -DCLANG_DEFAULT_CXX_STDLIB=libc++"
llvm_additional_cmake="${llvm_additional_cmake} -DCLANG_DEFAULT_LINKER=lld"
llvm_additional_cmake="${llvm_additional_cmake} -DCLANG_DEFAULT_RTLIB=compiler-rt"
llvm_additional_cmake="${llvm_additional_cmake} -DLLVM_USE_LINKER=lld"
llvm_additional_cmake="${llvm_additional_cmake} -DLLVM_ENABLE_LIBCXX=ON"
llvm_additional_cmake="${llvm_additional_cmake} -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON"

build_folder="build-llvm-final" \
cc_compiler="clang" \
cxx_compiler="clang++" \
install_dir="$PREFIX" \
llvm_projects='clang;compiler-rt;lld' \
targets_to_build="X86;BPF" \
additional_compiler_flags="" \
additional_linker_flags="-rtlib=compiler-rt -l:libc++abi.a -ldl -lpthread" \
additional_cmake="${llvm_additional_cmake}" \
build_llvm


CURRENT_DIR=$TOOLCHAIN_DIR/final
SYSROOT=$TOOLCHAIN_DIR/final/$TUPLE/$TUPLE/sysroot
PREFIX=$SYSROOT/usr

# Remove the static libclang/liblld/libLLVM and shared libc++/libunwind libraries from the sysroot.
( cd $PREFIX/lib; \
  rm libclang*.a; \
  rm liblld*.a; \
  rm libLLVM*.a; \
  rm libc++*.so.*; \
  rm libunwind*.so.*)

echo "Complete"
