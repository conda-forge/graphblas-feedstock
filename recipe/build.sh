#!/bin/bash

# make sure CMake install goes in the right place
export INSTALL="${PREFIX}"
# Use JITINIT=2 (=run) to use pre-JIT kernels that don't need a compiler at runtime
export CMAKE_OPTIONS="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DJITINIT=2"
if [[ "$OSTYPE" != "linux"* ]]; then
  export CMAKE_OPTIONS="-DGBNCPUFEAT=1 ${CMAKE_OPTIONS}"
fi

# Show cmake output on failures
trap "cat $SRC_DIR/build/CMakeFiles/CMakeOutput.log $SRC_DIR/build/CMakeFiles/CMakeError.log" ERR
# make SuiteSparse
make library VERBOSE=1 JOBS=16
make install VERBOSE=1
# forcibly remove the static library
rm -f ${PREFIX}/lib/libgraphblas.a
