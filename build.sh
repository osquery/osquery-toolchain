#!/bin/bash
# Copyright (c) 2014-present, The osquery authors
#
# This source code is licensed as defined by the LICENSE file found in the
# root directory of this source tree.
#
# SPDX-License-Identifier: (Apache-2.0 OR GPL-2.0-only)

# Heavily influenced by https://github.com/theopolis/build-anywhere
# Version 1.0.0

function build_gcc() {
  # Clone and build CrosstoolNG.
  if [[ ! -d $CURRENT_DIR/crosstool-ng ]]; then
    ( cd $CURRENT_DIR; \
      git clone https://github.com/crosstool-ng/crosstool-ng -b crosstool-ng-1.24.0 --single-branch )
  fi

  # Use our own config that sets a legacy glibc.
  cp ./crosstool-ng-config-$MACHINE $CURRENT_DIR/crosstool-ng/.config

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
            -DLLVM_ENABLE_PIC=ON \
            -DLLVM_DEFAULT_TARGET_TRIPLE=${TUPLE} \
            ${additional_cmake} \
            ../llvm && \
      cmake --build . -j ${PARALLEL_JOBS} && \
      cmake --build . --target install -j ${PARALLEL_JOBS} \
    )

  fi
}

function build_compiler-rt-builtins() {

  if [[ ! -e ${install_dir}/lib/linux/libclang_rt.builtins-$MACHINE.a ]]; then

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
            -DLLVM_ENABLE_PIC=ON \
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

#-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
function build_compiler_libs() {

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
            -DLLVM_ENABLE_PIC=ON \
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
            -DLIBUNWIND_ENABLE_STATIC=ON \
            -DLIBUNWIND_ENABLE_SHARED=OFF \
            ${additional_cmake} \
            ../llvm && \
      cmake --build . --target cxx -j ${PARALLEL_JOBS} && \
      cmake --build . --target install-cxx -j ${PARALLEL_JOBS} && \
      cmake --build . --target install-cxxabi -j ${PARALLEL_JOBS} && \
      cmake --build . --target install-unwind -j ${PARALLEL_JOBS}
    )
  fi
}

function make_symlink_real() {
  symlink=$1

  # It has been already processed
  if [ ! -L "$symlink" ]; then
    return
  fi

  if [ ! -e "$symlink" ]; then
    echo "The symlink $symlink doesn't exists"
    exit 1
  fi

  real_path=`readlink -f "$symlink"`
  symlink_name=`basename "$symlink"`

  if [ ! -e "$real_path" ]; then
    echo "The symlink $symlink links to $real_path which is a broken path"
    exit 1
  fi

  symlink_parent_folder=`dirname "$symlink"`
  rm "$symlink"

  if [ -d "$real_path" ]; then
    cp -r "$real_path" "$symlink_parent_folder/$symlink_name"
  else
    cp "$real_path" "$symlink_parent_folder/$symlink_name"
  fi
}

set -e

MACHINE="$(uname -m)"
if [ "$MACHINE" = "x86_64" ]
then
  LLVM_MACHINE="X86"
elif [ "$MACHINE" = "aarch64" ]
then
  LLVM_MACHINE="AArch64"
else
  echo "Unspported architecture" 1>&2
  exit 1
fi

source ./config

TOOLCHAIN_DIR=$1
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# We are already at the final stage, nothing to do
if [ -e $TOOLCHAIN_DIR/final/sysroot ]; then
  echo "Nothing to do. If you want to redo the final stage please delete the $TOOLCHAIN_DIR/final/sysroot folder"
  exit 0
fi

## STAGE 0 ##
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
if [[ ! -e $STAGE1_SYSROOT/usr/lib/gcc ]]; then
  ( cd $STAGE1_SYSROOT/usr/lib; \
    ln -s ../../../../lib/gcc $STAGE1_SYSROOT/usr/lib )
fi

FINAL_SYSROOT=$TOOLCHAIN_DIR/final/$TUPLE/$TUPLE/sysroot
if [[ ! -e $FINAL_SYSROOT/usr/lib/gcc ]]; then
  ( cd $FINAL_SYSROOT/usr/lib; \
    ln -s ../../../../lib/gcc $FINAL_SYSROOT/usr/lib )
fi

## STAGE 1 ##
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
targets_to_build="$LLVM_MACHINE" \
additional_linker_flags="" \
additional_compiler_flags="-s" \
additional_cmake="" \
build_llvm

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
targets_to_build="$LLVM_MACHINE;BPF" \
additional_linker_flags="" \
additional_cmake="" \
build_compiler_libs

build_folder="build-libcxx" \
cc_compiler="clang" \
cxx_compiler="clang++" \
install_dir="$TOOLCHAIN_DIR/final/$TUPLE/$TUPLE/sysroot/usr" \
llvm_projects='libcxx;libcxxabi;libunwind' \
targets_to_build="$LLVM_MACHINE;BPF" \
additional_linker_flags="" \
additional_cmake="" \
build_compiler_libs

# Remove the static libclang/liblld from the sysroot
( cd $PREFIX/lib; \
  rm -f libclang*.a; \
  rm -f liblld*.a)

## FINAL ##
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
llvm_projects='clang;compiler-rt;lld;clang-tools-extra' \
targets_to_build="$LLVM_MACHINE;BPF" \
additional_compiler_flags="" \
additional_linker_flags="-rtlib=compiler-rt -l:libc++abi.a -ldl -lpthread" \
additional_cmake="${llvm_additional_cmake}" \
build_llvm

CURRENT_DIR=$TOOLCHAIN_DIR/final
SYSROOT=$TOOLCHAIN_DIR/final/$TUPLE/$TUPLE/sysroot
PREFIX=$SYSROOT/usr

# Remove all the versions of libstdc++ from the sysroot.
( cd $PREFIX/lib; \
  rm -f libstdc*)

# Remove unused GCC binaries
( cd $PREFIX/bin; \
  rm -f gcc; \
  rm -f g++; \
  rm -f gcc-${GCC_VERSION}; \
  rm -f c++; \
  rm -f cc; \
  rm -f ld; \
  rm -f ld.bfd)

# Remove crosstool-ng leftovers
( cd $PREFIX/bin; \
  rm -f ct-ng.config)

symlinks_to_transform=(
  lib/gcc
  bin/addr2line
  bin/ar bin/as
  bin/c++filt
  bin/cpp
  bin/elfedit
  bin/gcc-ar
  bin/gcc-nm
  bin/gcc-ranlib
  bin/gcov
  bin/gcov-dump
  bin/gcov-tool
  bin/gprof
  bin/nm
  bin/objcopy
  bin/objdump
  bin/populate
  bin/ranlib
  bin/readelf
  bin/size
  bin/strings
  bin/strip
)

for symlink in "${symlinks_to_transform[@]}"
do
  make_symlink_real "$PREFIX/$symlink"
done

remaining_symlinks=`find "$SYSROOT" -type l`
real_sysroot=`realpath ${SYSROOT}`

symlinks_to_fix=0
while read line
do
  real_path=`readlink -f "$line"`
  if [[ ! "$real_path" == "$real_sysroot/"* ]]; then
    symlinks_to_fix=1
    echo "$line -> $real_path"
  fi
done <<< "$remaining_symlinks"

if [ $symlinks_to_fix -ne 0 ]; then
  echo -e "\nThe above symlinks point out of the sysroot, please fix the script so that they are converted to a real file or are removed"
  exit 1
fi

if [ $KEEP_INTERMEDIATE_STAGES -eq 0 ]; then
  mv "$SYSROOT" "$CURRENT_DIR"
  rm -r "$CURRENT_DIR/$TUPLE"
  rm -r "$TOOLCHAIN_DIR/stage1"
  rm -rf "$LLVM_SRC"	# Force needed for .git
else
  ln -s "$SYSROOT" "$CURRENT_DIR"
fi

echo "Complete"
