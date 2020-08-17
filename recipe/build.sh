#!/bin/bash

# make sure CMake install goes in the right place
export INSTALL="${PREFIX}"
export CMAKE_OPTIONS="-DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release"

# make SuiteSparse
make library VERBOSE=1
make install VERBOSE=1
# forcibly remove the static library
rm -f ${PREFIX}/lib/libgraphblas.a
