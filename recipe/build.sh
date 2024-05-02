#!/bin/bash
set -ex
# Use JITINIT=2 (=run) to use pre-JIT kernels that don't need a compiler at runtime
export CMAKE_ARGS="${CMAKE_ARGS} \
  -DCMAKE_INSTALL_PREFIX=${PREFIX}\
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DGRAPHBLAS_JITINIT=2 \
"

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
