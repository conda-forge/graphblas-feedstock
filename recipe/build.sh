#!/bin/bash
set -ex
# Use JITINIT=2 (=run) to use pre-JIT kernels that don't need a compiler at runtime
export CMAKE_ARGS="${CMAKE_ARGS} \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}\
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DGRAPHBLAS_JITINIT=2 \
  -DCMAKE_C_COMPILER=${CC} \
  -DCMAKE_CXX_COMPILER=${CXX} \
  -DSUITESPARSE_USE_FORTRAN=OFF \
  -DSUITESPARSE_USE_CUDA=OFF \
  -DSUITESPARSE_USE_OPENMP=ON \
  -DSUITESPARSE_USE_STRICT=ON \
"

# Why each of the settings above:
#
# CMAKE_C_COMPILER/CMAKE_CXX_COMPILER: pin the compiler CMake uses. Without
# this it can pick up ${PREFIX}/bin/${HOST}-cc, which the GCC toolchain
# installs as a symlink to ${HOST}-gcc. That is how graphblas 10.5.0 came to
# be compiled by GNU gcc 15.3.0 on osx-arm64 (`about["compiler_name"]`).
#
# SUITESPARSE_USE_FORTRAN=OFF: GraphBLAS compiles no Fortran. Saying so is
# the supported way to satisfy the common SuiteSparse config, and it lets the
# recipe drop {{ compiler('fortran') }}. That matters here: on osx-arm64,
# gfortran_osx-arm64 15.3.0 depends on gcc_osx-arm64 (14.3.0 depended on
# clang_osx-arm64), so requiring a Fortran compiler now drags a whole GCC
# toolchain into the build environment.
#
# SUITESPARSE_USE_CUDA=OFF: this one is *not* optional under strict mode.
# SuiteSparsePolicy.cmake defaults SUITESPARSE_USE_CUDA to ON, so strict mode
# would abort with "CUDA required for SuiteSparse but not found". GraphBLAS
# itself hard-sets GRAPHBLAS_USE_CUDA=OFF ("not deployed in production"), so
# turning the SuiteSparse-wide switch off loses nothing.
#
# SUITESPARSE_USE_OPENMP=ON: the default, stated explicitly so that the strict
# check below is actually load-bearing -- strict only errors on a *requested*
# feature that is missing.
#
# SUITESPARSE_USE_STRICT=ON: without it, GraphBLAS only *warns* when OpenMP
# is not found and happily builds a serial library (CMakeLists.txt ~line 177,
# and the warning at ~line 619). graphblas 10.5.0 shipped exactly that on
# osx-arm64 -- no libomp linkage, no omp symbols -- while still carrying
# `run: llvm-openmp`, so nothing about the package looked wrong. With strict
# on, a missing OpenMP fails the build instead. The only other features strict
# mode checks -- Fortran and CUDA -- are both explicitly disabled above.

if [[ "${target_platform}" != "${build_platform}" ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_CROSSCOMPILING=ON"
  if [[ "${build_platform}" == "osx-64" ]]; then
    # seem to need cross toolchain for jit setup
    # but only on mac-arm
    export CMAKE_ARGS="${CMAKE_ARGS} -DGRAPHBLAS_CROSS_TOOLCHAIN_FLAGS_NATIVE=-DCMAKE_TOOLCHAIN_FILE=/${RECIPE_DIR}/native-toolchain.cmake"
  fi
fi

if [[ "${target_platform}" != "linux"* ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DGBNCPUFEAT=1"
fi

# Show cmake output on failures
trap "cat $SRC_DIR/build/CMakeFiles/CMakeOutput.log $SRC_DIR/build/CMakeFiles/CMakeError.log" ERR
# make SuiteSparse
cmake -B build ${CMAKE_ARGS} .
cmake --build build --verbose --parallel "${CPU_COUNT:-1}"
cmake --install build
