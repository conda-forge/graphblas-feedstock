#!/bin/bash

# make sure CMake install goes in the right place
export INSTALL="${PREFIX}"
# Use JITINIT=2 (=run) to use pre-JIT kernels that don't need a compiler at runtime
export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DJITINIT=2"
if [[ "$OSTYPE" != "linux"* ]]; then
  export CMAKE_ARGS="${CMAKE_ARGS} -DGBNCPUFEAT=1"
fi

# Show cmake output on failures
trap "cat $SRC_DIR/build/CMakeFiles/CMakeOutput.log $SRC_DIR/build/CMakeFiles/CMakeError.log" ERR
# make SuiteSparse
cmake -B build ${CMAKE_ARGS} .
cmake --build build --verbose --parallel "${CPU_COUNT:-1}"
cmake --install build
